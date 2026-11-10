import Foundation
import Testing

@testable import ScanLabCore

@Suite("Sample meshes")
struct SampleMeshesTests {
    @Test("the stepped block is 60 × 40 × 20 mm")
    func dimensions() throws {
        let box = try #require(SampleMeshes.stepBlock().boundingBox)
        #expect(isClose(box.minimum, .zero, tolerance: 1e-12))
        #expect(isClose(box.size, SampleMeshes.stepBlockSize, tolerance: 1e-12))
        #expect(Units.formatDimensions(box.size) == "60.0 × 40.0 × 20.0 mm")
    }

    @Test("the coarse shape has 310 faces and each subdivision multiplies by four")
    func faceCounts() {
        #expect(SampleMeshes.stepBlock(subdivisions: 0).faceCount == 310)
        #expect(SampleMeshes.stepBlock(subdivisions: 1).faceCount == 1_240)
        #expect(SampleMeshes.stepBlock().faceCount == 19_840)
    }

    @Test("the stepped block is closed, faces outwards and has the expected volume", arguments: [0, 3])
    func closedAndOutward(subdivisions: Int) {
        let mesh = SampleMeshes.stepBlock(subdivisions: subdivisions)
        #expect(mesh.openEdgeCount == 0)
        // Base 60 × 40 × 10, step 20 × 40 × 5, and a 48-sided boss of radius 8 and
        // height 10, in cubic millimetres.
        let bossArea = 0.5 * 48 * 64 * sin(2 * Double.pi / 48)
        let expected = (24_000 + 4_000 + bossArea * 10) * 1e-9
        #expect(isClose(mesh.volume, expected, tolerance: expected * 1e-9))
    }

    @Test("every face has some area")
    func noSlivers() {
        let mesh = SampleMeshes.stepBlock(subdivisions: 0)
        #expect(mesh.triangles.indices.allSatisfy { mesh.faceNormal($0) != .zero })
    }

    @Test("subdividing keeps the shape and refuses negative counts")
    func subdividing() throws {
        let cube = TestMeshes.cube()
        #expect(SampleMeshes.subdivided(cube, times: -1) == cube)
        let finer = SampleMeshes.subdivided(cube, times: 2)
        #expect(finer.faceCount == 192)
        #expect(finer.openEdgeCount == 0)
        #expect(isClose(finer.volume, 1))
        #expect(finer.boundingBox == cube.boundingBox)
    }

    @Test("the builder merges shared corners and turns faces outwards")
    func builder() {
        var builder = MeshBuilder()
        builder.triangle(.zero, Vec3(0, 1, 0), Vec3(1, 0, 0), outward: Vec3(0, 0, 1))
        builder.triangle(Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(1, 1, 0), outward: Vec3(0, 0, 1))
        let mesh = builder.mesh
        #expect(mesh.vertexCount == 4)
        #expect(mesh.faceNormal(0) == Vec3(0, 0, 1))
        #expect(mesh.faceNormal(1) == Vec3(0, 0, 1))
    }
}
