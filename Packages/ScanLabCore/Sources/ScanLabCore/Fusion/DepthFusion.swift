import Foundation

/// Counts that show how fusion is going, for the Capture screen and the log (DF-9, DF-10).
public struct FusionStats: Equatable, Sendable {
    /// Depth pictures fused so far.
    public var framesFused = 0
    /// Pictures refused because their camera numbers were unusable.
    public var framesRejected = 0
    /// Readings that passed the range and confidence checks (DF-2).
    public var readingsUsed = 0
    /// Blocks of 8 × 8 × 8 cubes in use (DF-6).
    public var blocks = 0
    /// True once the memory cap stopped new areas being added (DF-6).
    public var isFull = false

    public init() {}
}

/// The fused surface and what was tidied away (DF-4).
public struct FusedMesh: Equatable, Sendable {
    public let mesh: Mesh
    public let piecesDropped: Int
    public let facesDropped: Int

    public init(mesh: Mesh, piecesDropped: Int, facesDropped: Int) {
        self.mesh = mesh
        self.piecesDropped = piecesDropped
        self.facesDropped = facesDropped
    }
}

/// Fuses depth pictures into one surface (U14, ADR-029).
///
/// The idea in plain terms: picture a fine 3D grid of small cubes around the subject.
/// Each depth reading says "along this line of sight, the surface is *here*". Cubes on
/// that line just in front of the point are told "you are outside, this far from the
/// surface"; cubes just behind it are told "you are inside". Every cube keeps a running
/// average of what it has been told. One reading is noisy, but hundreds of readings from
/// different positions average the noise away. Finally the surface is drawn wherever the
/// average flips from outside to inside (`SurfaceNets`).
///
/// Not thread-safe: the App keeps one instance on one serial queue.
public final class DepthFusion {
    public let settings: FusionSettings
    public private(set) var stats = FusionStats()
    var volume: VoxelVolume

    public init(settings: FusionSettings = .standard) {
        self.settings = settings
        volume = VoxelVolume(voxelSize: settings.voxelSize, maximumBlocks: settings.maximumBlocks)
    }

    /// Fuses one picture and returns how many of its readings were used.
    @discardableResult
    public func integrate(_ frame: FusionFrame) -> Int {
        guard frame.intrinsics.isUsable, frame.cameraPosition.isFinite, settings.voxelSize > 0,
            settings.band > 0
        else {
            stats.framesRejected += 1
            return 0
        }
        let depth = frame.depth
        let step = max(settings.pixelStep, 1)
        var used = 0
        volume.beginPicture()
        for row in stride(from: 0, to: depth.height, by: step) {
            for column in stride(from: 0, to: depth.width, by: step) {
                guard let weight = weight(of: depth, column: column, row: row) else { continue }
                let metres = Double(depth.depths[row * depth.width + column])
                let local = frame.cameraPoint(column: column, row: row, depth: metres)
                fuseReading(towards: frame.cameraToWorld.apply(to: local), in: frame, weight: weight)
                used += 1
            }
        }
        stats.framesFused += 1
        stats.readingsUsed += used
        stats.blocks = volume.blockCount
        stats.isFull = volume.isFull
        return used
    }

    /// Draws the surface and drops loose specks (DF-3, DF-4).
    public func makeMesh() -> FusedMesh {
        var lookup = volume
        let raw = SurfaceNets.mesh(from: &lookup, minimumWeight: Float(settings.minimumWeightToDraw))
        return MeshPieces.droppingSmallPieces(of: raw, smallestFaces: settings.smallestPieceFaces)
    }

    /// How much a reading counts, or nil when it must be ignored (DF-2).
    func weight(of depth: DepthFrame, column: Int, row: Int) -> Double? {
        let metres = depth.depths[row * depth.width + column]
        guard DepthFrame.isValid(metres), Double(metres) >= settings.nearestDepth,
            Double(metres) <= settings.farthestDepth
        else { return nil }
        guard let level = depth.confidenceLevel(column: column, row: row) else {
            // No confidence map at all: every reading is trusted equally.
            return depth.hasConfidence ? nil : 1
        }
        switch level {
        case .high: return 1
        case .medium: return settings.mediumConfidenceWeight > 0 ? settings.mediumConfidenceWeight : nil
        case .low: return nil
        }
    }

    /// Updates the cubes near one measured point (DF-1).
    ///
    /// The reading's line of sight is only used to *find* cubes worth updating: it is
    /// walked in half-cube steps from `band` in front of the point to `band` behind it.
    /// Each cube found is then judged on its own: its centre is projected back into the
    /// depth picture, and its distance in front of the surface is the depth read at that
    /// spot minus the cube's own depth. Because every line of sight that finds a cube
    /// gives it the same answer, the order of the readings does not matter. Distances
    /// are divided by the band, so every stored value lies between −1 and 1.
    func fuseReading(towards surface: Vec3, in frame: FusionFrame, weight: Double) {
        let offset = surface - frame.cameraPosition
        let range = offset.length
        guard range > 0, range.isFinite else { return }
        let direction = offset / range
        let band = settings.band
        let halfStep = settings.voxelSize / 2
        var previous: VoxelIndex?
        var travelled = -band
        while travelled <= band {
            let index = volume.index(of: surface + direction * travelled)
            travelled += halfStep
            guard index != previous else { continue }
            previous = index
            guard let inFront = distanceInFront(of: volume.centre(of: index), in: frame), inFront >= -band
            else { continue }
            volume.add(
                distance: Float(min(inFront, band) / band), weight: Float(weight), to: index,
                maximumWeight: Float(settings.maximumWeight))
        }
    }

    /// How far a point is in front of the surface the picture saw, measured along the
    /// camera's viewing direction; nil when the point is behind the camera, outside the
    /// picture, or there is no usable reading where it lands.
    func distanceInFront(of point: Vec3, in frame: FusionFrame) -> Double? {
        let local = frame.worldToCamera(point)
        let pointDepth = -local.z
        guard pointDepth > 0 else { return nil }
        let lens = frame.intrinsics
        let column = lens.focalX * local.x / pointDepth + lens.centreX
        let row = -lens.focalY * local.y / pointDepth + lens.centreY
        guard let surfaceDepth = depth(at: column, row, in: frame.depth) else { return nil }
        return surfaceDepth - pointDepth
    }

    /// The depth reading at a spot between pixel centres.
    ///
    /// When the four surrounding readings are all usable and agree to within the band,
    /// they are blended by how close the spot is to each ("bilinear" blending), which
    /// removes the staircase a single pixel would give on a slanted surface. Across an
    /// edge they disagree, so the nearest reading is used instead of a blend that would
    /// invent a surface in mid-air.
    func depth(at column: Double, _ row: Double, in picture: DepthFrame) -> Double? {
        guard column.isFinite, row.isFinite, column > -0.5, row > -0.5,
            column < Double(picture.width) - 0.5, row < Double(picture.height) - 0.5
        else { return nil }
        let left = Int(column.rounded(.down))
        let top = Int(row.rounded(.down))
        if left >= 0, top >= 0, left + 1 < picture.width, top + 1 < picture.height {
            let corners = [(left, top), (left + 1, top), (left, top + 1), (left + 1, top + 1)]
            let values = corners.compactMap { usableDepth(picture, column: $0.0, row: $0.1) }
            if values.count == 4, let low = values.min(), let high = values.max(), high - low < settings.band {
                let across = column - Double(left)
                let down = row - Double(top)
                let upper = values[0] + (values[1] - values[0]) * across
                let lower = values[2] + (values[3] - values[2]) * across
                return upper + (lower - upper) * down
            }
        }
        return usableDepth(picture, column: Int(column.rounded()), row: Int(row.rounded()))
    }

    private func usableDepth(_ picture: DepthFrame, column: Int, row: Int) -> Double? {
        guard (0..<picture.width).contains(column), (0..<picture.height).contains(row),
            weight(of: picture, column: column, row: row) != nil
        else { return nil }
        return Double(picture.depths[row * picture.width + column])
    }
}
