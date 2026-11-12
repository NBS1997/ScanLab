import Foundation
import Testing

@testable import ScanLabCore

/// Synthetic scenes for the fusion tests: depth pictures of a known shape, made by
/// tracing each pixel's line of sight, from known camera positions.
enum SyntheticDepth {
    static let width = 64
    static let height = 48
    static let intrinsics = CameraIntrinsics(focalX: 120, focalY: 120, centreX: 32, centreY: 24)

    /// A camera at `eye` looking at `target`, with world +y as up. Its axes follow the
    /// platform: x right, y up, looking along −z.
    static func camera(at eye: Vec3, lookingAt target: Vec3) -> Transform {
        let forward = (target - eye).normalised
        let right = forward.cross(Vec3(0, 1, 0)).normalised
        let upward = right.cross(forward)
        let back = -forward
        // The columns of the turn are the camera's axes in world terms.
        return Transform(
            xRow: Vec3(right.x, upward.x, back.x), yRow: Vec3(right.y, upward.y, back.y),
            zRow: Vec3(right.z, upward.z, back.z),
            translation: eye)
    }

    /// The world direction of a pixel's line of sight, scaled so its part along the
    /// viewing direction is 1 (so distance along it equals the depth reading).
    static func ray(column: Int, row: Int, camera: Transform) -> Vec3 {
        let local = Vec3(
            (Double(column) - intrinsics.centreX) / intrinsics.focalX,
            -(Double(row) - intrinsics.centreY) / intrinsics.focalY, -1)
        return camera.apply(to: local) - camera.translation
    }

    /// A depth picture of a sphere; pixels that miss it have no reading. `noise` adds a
    /// repeatable wobble of up to ± that many metres.
    static func sphere(
        centre: Vec3, radius: Double, camera: Transform, noise: Double = 0, confidence: UInt8? = 2, seed: UInt64 = 1
    ) -> FusionFrame {
        var random = SeededRandom(seed: seed)
        var depths = [Float](repeating: .nan, count: width * height)
        for row in 0..<height {
            for column in 0..<width {
                let direction = ray(column: column, row: row, camera: camera)
                // Solve |eye + t·direction − centre| = radius for the nearer t.
                let offset = camera.translation - centre
                let a = direction.dot(direction)
                let b = 2 * offset.dot(direction)
                let c = offset.dot(offset) - radius * radius
                let disc = b * b - 4 * a * c
                guard disc >= 0 else { continue }
                let depth = (-b - disc.squareRoot()) / (2 * a)
                depths[row * width + column] = Float(depth + noise * (random.unit() * 2 - 1))
            }
        }
        return frame(depths: depths, camera: camera, confidence: confidence)
    }

    /// A depth picture where every pixel reads `depth`: a flat wall facing the camera.
    static func wall(depth: Float, camera: Transform = .identity, confidence: UInt8? = 2) -> FusionFrame {
        frame(depths: [Float](repeating: depth, count: width * height), camera: camera, confidence: confidence)
    }

    static func frame(depths: [Float], camera: Transform, confidence: UInt8?) -> FusionFrame {
        let levels = confidence.map { [UInt8](repeating: $0, count: depths.count) } ?? []
        guard let depth = DepthFrame(width: width, height: height, depths: depths, confidence: levels) else {
            fatalError("Synthetic depth sizes disagree")
        }
        return FusionFrame(depth: depth, intrinsics: intrinsics, cameraToWorld: camera)
    }

    /// Cameras on a ring around `centre`, plus two from above, all looking at it.
    static func ringOfCameras(around centre: Vec3, distance: Double, count: Int) -> [Transform] {
        var cameras: [Transform] = []
        for step in 0..<count {
            let angle = Double(step) / Double(count) * 2 * Double.pi
            let eye = centre + Vec3(cos(angle) * distance, 0.05, sin(angle) * distance)
            cameras.append(camera(at: eye, lookingAt: centre))
        }
        cameras.append(camera(at: centre + Vec3(0.02, distance, 0.1), lookingAt: centre))
        cameras.append(camera(at: centre + Vec3(-0.1, distance * 0.7, -0.1), lookingAt: centre))
        return cameras
    }
}

struct DepthFusionTests {
    let sphereCentre = Vec3(0, 0, -0.3)
    let sphereRadius = 0.05

    // MARK: - Camera numbers

    @Test func centrePixelLiesStraightAhead() {
        let frame = SyntheticDepth.wall(depth: 0.5)
        let point = frame.cameraPoint(column: 32, row: 24, depth: 0.5)
        #expect(point == Vec3(0, 0, -0.5))
    }

    @Test func pixelsRightAndBelowTheCentreGoRightAndDown() {
        let frame = SyntheticDepth.wall(depth: 0.5)
        let right = frame.cameraPoint(column: 44, row: 24, depth: 0.6)
        let below = frame.cameraPoint(column: 32, row: 36, depth: 0.6)
        #expect(abs(right.x - 0.06) < 1e-12)
        #expect(abs(below.y + 0.06) < 1e-12)
    }

    @Test func intrinsicsScaleWithThePicture() {
        let colour = CameraIntrinsics(focalX: 1_440, focalY: 1_440, centreX: 960, centreY: 720)
        let depth = colour.scaled(by: 256.0 / 1_920.0)
        #expect(abs(depth.focalX - 192) < 1e-9)
        #expect(abs(depth.centreX - 128) < 1e-9)
        #expect(abs(depth.centreY - 96) < 1e-9)
        #expect(depth.isUsable)
        #expect(!CameraIntrinsics(focalX: 0, focalY: 1, centreX: 0, centreY: 0).isUsable)
    }

    @Test func worldToCameraUndoesCameraToWorld() {
        let camera = SyntheticDepth.camera(at: Vec3(0.2, 0.1, 0.3), lookingAt: Vec3(0, 0, -0.3))
        let frame = SyntheticDepth.wall(depth: 0.4, camera: camera)
        let local = Vec3(0.01, -0.02, -0.35)
        let back = frame.worldToCamera(camera.apply(to: local))
        #expect(back.distance(to: local) < 1e-12)
    }

    @Test func depthBetweenPixelsIsBlendedButNotAcrossEdges() {
        let fusion = DepthFusion()
        // Left half reads 0.30 m, right half 0.50 m: an edge between columns 31 and 32.
        var depths = [Float](repeating: 0.3, count: SyntheticDepth.width * SyntheticDepth.height)
        for row in 0..<SyntheticDepth.height {
            for column in 32..<SyntheticDepth.width {
                depths[row * SyntheticDepth.width + column] = 0.5
            }
        }
        let picture = SyntheticDepth.frame(depths: depths, camera: .identity, confidence: 2).depth
        let flat = fusion.depth(at: 10.5, 10.5, in: picture)
        #expect(abs((flat ?? 0) - 0.3) < 1e-6)
        // Halfway across the edge the nearer pixel wins (0.5 rounds up to column 32).
        let edge = fusion.depth(at: 31.4, 10, in: picture)
        #expect(abs((edge ?? 0) - 0.3) < 1e-6)
        #expect(fusion.depth(at: -1, 10, in: picture) == nil)
        #expect(fusion.depth(at: 10, 48, in: picture) == nil)
    }

    @Test func pointsBehindTheCameraAreNotJudged() {
        let fusion = DepthFusion()
        let frame = SyntheticDepth.wall(depth: 0.3)
        #expect(fusion.distanceInFront(of: Vec3(0, 0, 0.2), in: frame) == nil)
        let inFront = fusion.distanceInFront(of: Vec3(0, 0, -0.25), in: frame)
        #expect(abs((inFront ?? 0) - 0.05) < 1e-6)
    }

    // MARK: - Fusing known shapes

    @Test func wallIsFusedFlatAndFacingTheCamera() throws {
        let fusion = DepthFusion()
        for _ in 0..<3 {
            fusion.integrate(SyntheticDepth.wall(depth: 0.3))
        }
        let fused = fusion.makeMesh().mesh
        #expect(fused.faceCount > 100)
        for vertex in fused.vertices {
            #expect(abs(vertex.z + 0.3) < 0.001)
        }
        // The camera is at the origin, so the wall's outside faces +z.
        let facing = fused.triangles.indices.filter { fused.faceNormal($0).z > 0.9 }
        #expect(Double(facing.count) / Double(fused.faceCount) > 0.95)
    }

    @Test func sphereFromManyViewsIsWithinAMillimetre() throws {
        let fused = fuseSphere(noise: 0)
        #expect(fused.faceCount > 300)
        let errors = fused.vertices.map { abs($0.distance(to: sphereCentre) - sphereRadius) }
        let mean = errors.reduce(0, +) / Double(errors.count)
        #expect(mean < 0.001)
        #expect(errors.max() ?? 1 < 0.004)
    }

    @Test func sphereFacesPointOutwards() throws {
        let fused = fuseSphere(noise: 0)
        let outward = fused.triangles.indices.filter { face in
            let triangle = fused.triangles[face]
            let middle = (fused.vertices[triangle.a] + fused.vertices[triangle.b] + fused.vertices[triangle.c]) / 3
            return fused.faceNormal(face).dot(middle - sphereCentre) > 0
        }
        #expect(Double(outward.count) / Double(fused.faceCount) > 0.97)
    }

    @Test func noiseIsAveragedAway() throws {
        // Each reading wobbles by up to ±3 mm; averaging many views must do much better.
        let fused = fuseSphere(noise: 0.003)
        let errors = fused.vertices.map { abs($0.distance(to: sphereCentre) - sphereRadius) }
        let mean = errors.reduce(0, +) / Double(errors.count)
        #expect(mean < 0.0015)
    }

    @Test func fusedMeshIsAValidMesh() throws {
        let fused = fuseSphere(noise: 0.002)
        let rebuilt = try Mesh(vertices: fused.vertices, triangles: fused.triangles)
        #expect(rebuilt == fused)
    }

    // MARK: - Readings that must not count (DF-2, DF-3)

    @Test func lowConfidenceReadingsAreIgnored() {
        let fusion = DepthFusion()
        let used = fusion.integrate(SyntheticDepth.wall(depth: 0.3, confidence: 0))
        #expect(used == 0)
        #expect(fusion.stats.framesFused == 1)
        #expect(fusion.stats.blocks == 0)
        #expect(fusion.makeMesh().mesh.isEmpty)
    }

    @Test func readingsOutsideTheRangeAreIgnored() {
        let fusion = DepthFusion()
        #expect(fusion.integrate(SyntheticDepth.wall(depth: 1.5)) == 0)
        #expect(fusion.integrate(SyntheticDepth.wall(depth: 0.05)) == 0)
        #expect(fusion.integrate(SyntheticDepth.wall(depth: .nan)) == 0)
        #expect(fusion.integrate(SyntheticDepth.wall(depth: 0)) == 0)
        #expect(fusion.stats.readingsUsed == 0)
    }

    @Test func readingsWithoutAConfidenceMapAreTrusted() {
        let fusion = DepthFusion()
        let used = fusion.integrate(SyntheticDepth.wall(depth: 0.3, confidence: nil))
        #expect(used == SyntheticDepth.width * SyntheticDepth.height)
    }

    @Test func oneViewIsNotEnoughToDraw() {
        let fusion = DepthFusion()
        fusion.integrate(SyntheticDepth.wall(depth: 0.3))
        #expect(fusion.makeMesh().mesh.isEmpty)
        fusion.integrate(SyntheticDepth.wall(depth: 0.3))
        #expect(!fusion.makeMesh().mesh.isEmpty)
    }

    @Test func mediumConfidenceCountsLess() {
        let fusion = DepthFusion()
        // Four medium views weigh 1.4, still short of the 1.5 needed to draw.
        for _ in 0..<4 {
            fusion.integrate(SyntheticDepth.wall(depth: 0.3, confidence: 1))
        }
        #expect(fusion.stats.readingsUsed > 0)
        #expect(fusion.makeMesh().mesh.isEmpty)
        fusion.integrate(SyntheticDepth.wall(depth: 0.3, confidence: 1))
        #expect(!fusion.makeMesh().mesh.isEmpty)
    }

    @Test func unusableCameraNumbersRejectTheFrame() {
        let fusion = DepthFusion()
        let good = SyntheticDepth.wall(depth: 0.3)
        let broken = FusionFrame(
            depth: good.depth, intrinsics: CameraIntrinsics(focalX: 0, focalY: 0, centreX: 0, centreY: 0),
            cameraToWorld: .identity)
        #expect(fusion.integrate(broken) == 0)
        #expect(fusion.stats.framesRejected == 1)
        #expect(fusion.stats.framesFused == 0)
    }

    // MARK: - Memory cap (DF-6)

    @Test func memoryCapStopsNewAreasButKeepsExistingOnes() {
        var settings = FusionSettings()
        settings.maximumBlocks = 4
        let fusion = DepthFusion(settings: settings)
        fusion.integrate(SyntheticDepth.wall(depth: 0.3))
        #expect(fusion.stats.blocks == 4)
        #expect(fusion.stats.isFull)
        #expect(fusion.stats.readingsUsed > 0)
    }

    @Test func emptyFusionDrawsNothing() {
        let fused = DepthFusion().makeMesh()
        #expect(fused.mesh.isEmpty)
        #expect(fused.piecesDropped == 0)
    }

    @Test func settingsAreLogged() {
        let details = FusionSettings.standard.logDetails
        #expect(details["voxel mm"] == "4.0")
        #expect(details["band mm"] == "16.0")
        #expect(details["range m"] == "0.10-1.00")
    }

    // MARK: - Helpers

    private func fuseSphere(noise: Double) -> Mesh {
        let fusion = DepthFusion()
        let cameras = SyntheticDepth.ringOfCameras(around: sphereCentre, distance: 0.25, count: 10)
        for (number, camera) in cameras.enumerated() {
            for pass in 0..<2 {
                fusion.integrate(
                    SyntheticDepth.sphere(
                        centre: sphereCentre, radius: sphereRadius, camera: camera, noise: noise,
                        seed: UInt64(number * 10 + pass + 1)))
            }
        }
        return fusion.makeMesh().mesh
    }
}
