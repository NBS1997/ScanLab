import Foundation

@testable import ScanLabCore

/// Small meshes with known answers, shared by the geometry tests.
enum TestMeshes {
    /// Corners at the origin and 1 m along each axis; faces point outwards.
    /// Volume 1/6 m³, four faces, closed.
    static func tetrahedron() throws -> Mesh {
        try Mesh(
            vertices: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)],
            triangles: [Triangle(0, 2, 1), Triangle(0, 1, 3), Triangle(0, 3, 2), Triangle(1, 2, 3)])
    }

    /// A cube from the origin to `size` metres along each axis, twelve faces, closed.
    static func cube(size: Double = 1) -> Mesh {
        var builder = MeshBuilder()
        // Corner number bits: 1 = far in x, 2 = far in y, 4 = far in z.
        let corners: [Vec3] = (0..<8).map { (index: Int) -> Vec3 in
            let x = Double(index & 1)
            let y = Double((index >> 1) & 1)
            let z = Double((index >> 2) & 1)
            return Vec3(x, y, z) * size
        }
        let sides: [([Int], Vec3)] = [
            ([0, 1, 3, 2], Vec3(0, 0, -1)), ([4, 5, 7, 6], Vec3(0, 0, 1)),
            ([0, 1, 5, 4], Vec3(0, -1, 0)), ([2, 3, 7, 6], Vec3(0, 1, 0)),
            ([0, 2, 6, 4], Vec3(-1, 0, 0)), ([1, 3, 7, 5], Vec3(1, 0, 0)),
        ]
        for (indices, outward) in sides {
            builder.quad(indices.map { corners[$0] }, outward: outward)
        }
        return builder.mesh
    }

    /// A flat open square `size` metres across in the z = 0 plane, `cells` squares each
    /// way, two triangles per square, facing up.
    static func grid(cells: Int, size: Double = 1) -> Mesh {
        var builder = MeshBuilder()
        let step = size / Double(cells)
        for row in 0..<cells {
            for column in 0..<cells {
                let corner = Vec3(Double(column) * step, Double(row) * step, 0)
                let square = [
                    corner, corner + Vec3(step, 0, 0), corner + Vec3(step, step, 0), corner + Vec3(0, step, 0),
                ]
                builder.quad(square, outward: Vec3(0, 0, 1))
            }
        }
        return builder.mesh
    }

    /// A folder in the temporary directory, removed by `cleanUp`.
    static func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ScanLabTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func cleanUp(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }
}

/// The sample simplified once per test run and shared, because simplifying is the
/// slowest part of the suite in a debug build.
enum SampleResults {
    static let sample = SampleMeshes.stepBlock()
    static let fusion = Result { try MeshSimplifier.simplify(sample, targetFaces: 10_000) }
    static let light = Result { try MeshSimplifier.simplify(sample, targetFaces: 5_000) }

    static func simplified(to target: Int) throws -> Mesh {
        if target == 10_000 {
            return try fusion.get()
        }
        return try light.get()
    }
}

/// Whether two numbers agree to within `tolerance`.
func isClose(_ first: Double, _ second: Double, tolerance: Double = 1e-9) -> Bool {
    abs(first - second) <= tolerance
}

/// Whether two points agree to within `tolerance` in every direction.
func isClose(_ first: Vec3, _ second: Vec3, tolerance: Double = 1e-9) -> Bool {
    max(abs(first.x - second.x), abs(first.y - second.y), abs(first.z - second.z)) <= tolerance
}
