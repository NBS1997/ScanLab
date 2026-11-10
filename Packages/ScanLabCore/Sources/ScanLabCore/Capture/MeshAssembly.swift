import Foundation

/// One piece of a reconstructed surface as the platform hands it over: corner
/// positions relative to the piece's own origin, triangles that refer to those
/// corners, and where the piece sits in the world.
///
/// During a sweep the platform splits the world into blocks, each with its own small
/// mesh and its own position ("mesh anchors"). The adapter copies each block into one
/// of these, untouched, so that turning them into a single mesh can be tested here
/// without the phone.
public struct MeshPart: Equatable, Sendable {
    public var vertices: [Vec3]
    public var triangles: [Triangle]
    /// Moves the piece's corners into world positions.
    public var transform: Transform

    public init(vertices: [Vec3], triangles: [Triangle], transform: Transform = .identity) {
        self.vertices = vertices
        self.triangles = triangles
        self.transform = transform
    }
}

/// What happened while assembling, for the diagnostics log.
public struct AssemblyReport: Equatable, Sendable {
    /// Pieces that contributed at least one face.
    public var partsUsed = 0
    /// Faces handed in, across all pieces.
    public var facesIn = 0
    /// Faces dropped because they referred to a missing corner or a corner at an
    /// impossible position.
    public var invalidFaces = 0
    /// Faces dropped because they had no area (two corners in the same place).
    public var degenerateFaces = 0
    /// Faces dropped because they lay outside the crop box.
    public var croppedFaces = 0
    /// Corners that landed on an earlier corner and were joined to it.
    public var weldedVertices = 0

    public init() {}

    /// The report as log details.
    public var logDetails: [String: String] {
        [
            "parts": String(partsUsed), "facesIn": String(facesIn), "invalid": String(invalidFaces),
            "degenerate": String(degenerateFaces), "cropped": String(croppedFaces),
            "welded": String(weldedVertices),
        ]
    }
}

/// A finished mesh and how it was made.
public struct AssembledMesh: Equatable, Sendable {
    public var mesh: Mesh
    public var report: AssemblyReport
}

/// Turns the reconstruction's separate pieces into one mesh (used by the sweep
/// adapter at Finish).
///
/// Three things happen on the way:
/// 1. Every corner is moved to its world position with its piece's transform.
/// 2. **Welding:** neighbouring pieces each have their own copy of the corners along
///    their shared border. Corners closer together than `weldTolerance` are joined
///    into one, so the border is no longer a seam of open edges. The test is done by
///    rounding each position to a grid of that size and joining corners that round to
///    the same grid point: fast, and good enough for corners that are almost exactly
///    on top of each other.
/// 3. **Clean-up:** faces that refer to missing corners, have no area, or (when a
///    crop box is given) have their centre outside the box are dropped. Corners no
///    face uses are never added.
public enum MeshAssembly {
    /// Half a millimetre. The platform's surface is accurate to centimetres, so this
    /// joins true duplicates without merging separate detail.
    public static let defaultWeldTolerance = 0.000_5

    /// Faces smaller than this many square metres count as having no area. A face of
    /// 0.01 mm² is far below anything the sensor resolves.
    public static let minimumFaceArea = 1e-8

    /// - Parameters:
    ///   - weldTolerance: corners closer than about this many metres are joined. Zero
    ///     or less turns welding off.
    ///   - crop: when given, only faces whose centre is inside this box are kept.
    public static func assemble(
        _ parts: [MeshPart], weldTolerance: Double = defaultWeldTolerance, crop: Box? = nil
    ) -> AssembledMesh {
        var builder = Builder(welder: Welder(tolerance: weldTolerance), crop: crop)
        for part in parts {
            builder.add(part)
        }
        return AssembledMesh(
            mesh: Mesh(unchecked: builder.vertices, triangles: builder.triangles), report: builder.report)
    }

    /// Collects the merged corners and faces, one piece at a time.
    private struct Builder {
        var welder: Welder
        let crop: Box?
        var vertices: [Vec3] = []
        var triangles: [Triangle] = []
        var report = AssemblyReport()

        init(welder: Welder, crop: Box?) {
            self.welder = welder
            self.crop = crop
        }

        mutating func add(_ part: MeshPart) {
            report.facesIn += part.triangles.count
            let world = part.vertices.map { part.transform.apply(to: $0) }
            // Each piece's corner number → the merged mesh's corner number, filled in
            // the first time a kept face uses that corner.
            var merged = [Int?](repeating: nil, count: world.count)
            let facesBefore = triangles.count
            for triangle in part.triangles {
                add(triangle, world: world, merged: &merged)
            }
            if triangles.count > facesBefore {
                report.partsUsed += 1
            }
        }

        private mutating func add(_ triangle: Triangle, world: [Vec3], merged: inout [Int?]) {
            let corners = triangle.indices
            guard corners.allSatisfy({ world.indices.contains($0) && world[$0].isFinite }) else {
                report.invalidFaces += 1
                return
            }
            let points = corners.map { world[$0] }
            if let crop, !crop.contains((points[0] + points[1] + points[2]) / 3) {
                report.croppedFaces += 1
                return
            }
            let area = (points[1] - points[0]).cross(points[2] - points[0]).length / 2
            guard area >= MeshAssembly.minimumFaceArea else {
                report.degenerateFaces += 1
                return
            }
            var indices: [Int] = []
            for corner in corners {
                if let known = merged[corner] {
                    indices.append(known)
                    continue
                }
                let index = welder.index(for: world[corner], in: &vertices, report: &report)
                merged[corner] = index
                indices.append(index)
            }
            // Welding can pull two corners of a small face together.
            guard Set(indices).count == 3 else {
                report.degenerateFaces += 1
                return
            }
            triangles.append(Triangle(indices[0], indices[1], indices[2]))
        }
    }

    /// Hands out merged corner numbers, joining corners that round to the same grid
    /// point.
    private struct Welder {
        let tolerance: Double
        private var grid: [GridKey: Int] = [:]

        init(tolerance: Double) {
            self.tolerance = tolerance.isFinite && tolerance > 0 ? tolerance : 0
        }

        mutating func index(for point: Vec3, in vertices: inout [Vec3], report: inout AssemblyReport) -> Int {
            guard tolerance > 0, let key = GridKey(point, step: tolerance) else {
                vertices.append(point)
                return vertices.count - 1
            }
            if let existing = grid[key] {
                report.weldedVertices += 1
                return existing
            }
            vertices.append(point)
            grid[key] = vertices.count - 1
            return vertices.count - 1
        }
    }

    /// A position rounded to a grid. Nil when the position is too far out to round
    /// into whole numbers, in which case the corner is simply not welded.
    private struct GridKey: Hashable {
        let x: Int64
        let y: Int64
        let z: Int64

        init?(_ point: Vec3, step: Double) {
            guard let x = Int64(exactly: (point.x / step).rounded()),
                let y = Int64(exactly: (point.y / step).rounded()),
                let z = Int64(exactly: (point.z / step).rounded())
            else { return nil }
            self.x = x
            self.y = y
            self.z = z
        }
    }
}

extension Transform {
    /// Builds a transform from the 16 numbers of a 4 × 4 matrix listed column by
    /// column, the way the platform stores an anchor's position. The first three
    /// columns turn and resize; the fourth holds the move. The bottom row (0, 0, 0, 1
    /// for any position) is not needed. Nil unless exactly 16 finite numbers are given.
    public init?(columnMajor values: [Double]) {
        guard values.count == 16, values.allSatisfy(\.isFinite) else { return nil }
        self.init(
            xRow: Vec3(values[0], values[4], values[8]),
            yRow: Vec3(values[1], values[5], values[9]),
            zRow: Vec3(values[2], values[6], values[10]),
            translation: Vec3(values[12], values[13], values[14]))
    }
}
