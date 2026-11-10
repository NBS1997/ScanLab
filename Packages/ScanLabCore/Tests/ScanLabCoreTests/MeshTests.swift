import Foundation
import Testing

@testable import ScanLabCore

@Suite("Mesh")
struct MeshTests {
    @Test("a valid mesh reports its counts")
    func counts() throws {
        let mesh = try TestMeshes.tetrahedron()
        #expect(mesh.vertexCount == 4)
        #expect(mesh.faceCount == 4)
        #expect(!mesh.isEmpty)
        #expect(Mesh.empty.isEmpty)
    }

    @Test("an index past the end of the vertex list is refused")
    func indexTooLarge() {
        let corners = [Vec3.zero, Vec3(1, 0, 0), Vec3(0, 1, 0)]
        #expect(throws: MeshError.indexOutOfRange(triangle: 1, index: 3)) {
            try Mesh(vertices: corners, triangles: [Triangle(0, 1, 2), Triangle(0, 1, 3)])
        }
    }

    @Test("a negative index is refused")
    func negativeIndex() {
        #expect(throws: MeshError.indexOutOfRange(triangle: 0, index: -1)) {
            try Mesh(vertices: [.zero, Vec3(1, 0, 0), Vec3(0, 1, 0)], triangles: [Triangle(0, -1, 2)])
        }
    }

    @Test("a position that is not a number is refused")
    func nonFinite() {
        #expect(throws: MeshError.nonFiniteVertex(vertex: 1)) {
            try Mesh(vertices: [.zero, Vec3(.nan, 0, 0)], triangles: [])
        }
    }

    @Test("the bounding box counts only vertices that faces use")
    func boundingBox() throws {
        let mesh = try Mesh(
            vertices: [.zero, Vec3(2, 0, 0), Vec3(0, 3, 1), Vec3(100, 100, 100)],
            triangles: [Triangle(0, 1, 2)])
        #expect(mesh.boundingBox == Box(minimum: .zero, maximum: Vec3(2, 3, 1)))
    }

    @Test("an empty mesh has no bounding box, area or volume")
    func emptyMesh() {
        #expect(Mesh.empty.boundingBox == nil)
        #expect(Mesh.empty.surfaceArea == 0)
        #expect(Mesh.empty.volume == 0)
        #expect(Mesh.empty.openEdgeCount == 0)
    }

    @Test("volume and area of known closed shapes")
    func volumeAndArea() throws {
        let cube = TestMeshes.cube(size: 2)
        #expect(isClose(cube.volume, 8))
        #expect(isClose(cube.surfaceArea, 24))
        let tetrahedron = try TestMeshes.tetrahedron()
        #expect(isClose(tetrahedron.volume, 1.0 / 6))
    }

    @Test("closed shapes have no open edges; flat sheets do")
    func openEdges() throws {
        #expect(try TestMeshes.tetrahedron().openEdgeCount == 0)
        #expect(TestMeshes.cube().openEdgeCount == 0)
        #expect(TestMeshes.grid(cells: 3).openEdgeCount == 12)
        let single = try Mesh(vertices: [.zero, Vec3(1, 0, 0), Vec3(0, 1, 0)], triangles: [Triangle(0, 1, 2)])
        #expect(single.openEdgeCount == 3)
    }

    @Test("face normals point outwards with length 1, or are zero for a flat sliver")
    func normals() throws {
        let mesh = try Mesh(
            vertices: [.zero, Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(2, 0, 0)],
            triangles: [Triangle(0, 1, 2), Triangle(0, 1, 3)])
        #expect(mesh.faceNormal(0) == Vec3(0, 0, 1))
        #expect(mesh.faceNormal(1) == .zero)
    }

    @Test("scaling multiplies the size")
    func scaling() throws {
        let scaled = TestMeshes.cube(size: 0.06).scaled(by: 1000)
        let box = try #require(scaled.boundingBox)
        #expect(isClose(box.size, Vec3(60, 60, 60), tolerance: 1e-9))
    }

    @Test("a mirroring transform flips faces so the volume stays positive")
    func mirroring() {
        let mirror = Transform(xRow: Vec3(-1, 0, 0), yRow: Vec3(0, 1, 0), zRow: Vec3(0, 0, 1))
        let mirrored = TestMeshes.cube().transformed(by: mirror)
        #expect(isClose(mirrored.volume, 1))
        #expect(mirrored.triangles != TestMeshes.cube().triangles)
    }

    @Test("moving keeps faces and changes positions")
    func moving() {
        let moved = TestMeshes.cube().transformed(by: .moving(by: Vec3(1, 0, 0)))
        #expect(moved.triangles == TestMeshes.cube().triangles)
        #expect(moved.boundingBox?.minimum == Vec3(1, 0, 0))
    }

    @Test("compacting drops unused vertices and renumbers faces")
    func compacting() throws {
        let mesh = try Mesh(
            vertices: [Vec3(9, 9, 9), .zero, Vec3(1, 0, 0), Vec3(0, 1, 0)],
            triangles: [Triangle(1, 2, 3)])
        let compact = mesh.compacted()
        #expect(compact.vertices == [.zero, Vec3(1, 0, 0), Vec3(0, 1, 0)])
        #expect(compact.triangles == [Triangle(0, 1, 2)])
        #expect(Mesh.empty.compacted() == .empty)
    }

    @Test("edge keys ignore direction")
    func edgeKeys() {
        #expect(EdgeKey(3, 7) == EdgeKey(7, 3))
        #expect(EdgeKey(3, 7).low == 3)
        #expect(EdgeKey(3, 7).high == 7)
        #expect(EdgeKey(1, 9) < EdgeKey(2, 3))
    }
}
