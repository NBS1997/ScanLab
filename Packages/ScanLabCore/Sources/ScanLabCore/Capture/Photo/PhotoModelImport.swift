import Foundation

/// Turns the model file a photo build wrote into a Core `Mesh` ready for the library
/// (ADR-006): read the OBJ in metres, join up corners that share a position, turn it
/// z-up, and check it has faces.
public enum PhotoModelImport {
    /// The OBJ file in a folder the build wrote to, or `nil` when there is none. When
    /// there are several (there should not be), the first by name is used, so the
    /// choice is always the same.
    public static func modelFile(in folder: URL) -> URL? {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: folder.fileSystemPath) else { return nil }
        let objNames = names.filter { $0.lowercased().hasSuffix(".obj") }.sorted()
        return objNames.first.map { folder.appending(path: $0) }
    }

    /// Reads a built model. The platform writes y-up metres; the library stores z-up
    /// (shared rule from `AxisConversion`), so the mesh is turned on the way in.
    ///
    /// Throws `PhotoCaptureError.noModel` when the file has no faces, and
    /// `.buildFailed` with the reason when it cannot be read.
    public static func mesh(from url: URL) throws -> Mesh {
        let read: Mesh
        do {
            read = try MeshFiles.read(from: url, unit: .metres)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            throw PhotoCaptureError.buildFailed("the model file could not be read (\(reason))")
        }
        let mesh = welded(read).convertedFromYUp()
        guard !mesh.isEmpty else { throw PhotoCaptureError.noModel }
        return mesh
    }

    /// The same surface with corners at exactly the same position merged into one
    /// vertex, and faces that collapse to a line or point dropped.
    ///
    /// Why: a textured model can repeat a corner once for each texture patch it
    /// touches. To the simplifier (Export) those repeats look like cuts in the
    /// surface, which it must preserve, so the Fusion-friendly level would keep far
    /// more faces than needed. Merging exact repeats closes those false cuts without
    /// moving any point.
    public static func welded(_ mesh: Mesh) -> Mesh {
        var firstIndex: [Vec3: Int] = [:]
        var vertices: [Vec3] = []
        var remap = [Int](repeating: 0, count: mesh.vertices.count)
        for (index, vertex) in mesh.vertices.enumerated() {
            if let existing = firstIndex[vertex] {
                remap[index] = existing
            } else {
                firstIndex[vertex] = vertices.count
                remap[index] = vertices.count
                vertices.append(vertex)
            }
        }
        var triangles: [Triangle] = []
        triangles.reserveCapacity(mesh.triangles.count)
        for triangle in mesh.triangles {
            let joined = Triangle(remap[triangle.a], remap[triangle.b], remap[triangle.c])
            if joined.a != joined.b && joined.b != joined.c && joined.a != joined.c {
                triangles.append(joined)
            }
        }
        return Mesh(unchecked: vertices, triangles: triangles)
    }

    /// The largest dimension a photo scan is expected to have: Object Capture is for
    /// objects, and the owner uses it for parts under 150 mm.
    public static let largestExpectedSize = 2.0
    /// The smallest: below this the model is almost certainly in the wrong unit.
    public static let smallestExpectedSize = 0.002

    /// A warning for the log when the model's overall size is outside what a photo
    /// scan of an object should give, which would point at a unit mix-up; `nil` when
    /// it looks right. The scan is saved either way: its true size is judged against
    /// calipers (FR-4.4), not assumed.
    public static func sizeWarning(for mesh: Mesh) -> String? {
        guard let size = mesh.boundingBox?.size else { return "the model has no size" }
        let largest = max(size.x, size.y, size.z)
        if largest > largestExpectedSize {
            return "the model is \(Units.format(largest)) across, larger than expected for an object"
        }
        if largest < smallestExpectedSize {
            return "the model is only \(Units.format(largest)) across, smaller than expected"
        }
        return nil
    }
}
