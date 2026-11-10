import Foundation
import Testing

@testable import ScanLabCore

@Suite("Mesh assembly")
struct MeshAssemblyTests {
    /// A 1 m square in the x–y plane made of two triangles, corners at the origin.
    private func square(at offset: Vec3 = .zero) -> MeshPart {
        MeshPart(
            vertices: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0), Vec3(0, 1, 0)],
            triangles: [Triangle(0, 1, 2), Triangle(0, 2, 3)],
            transform: .moving(by: offset))
    }

    @Test("pieces are moved into the world and joined along shared borders")
    func mergesAndWelds() {
        // Two squares side by side share the edge at x = 1: two corners each.
        let result = MeshAssembly.assemble([square(), square(at: Vec3(1, 0, 0))])
        #expect(result.mesh.faceCount == 4)
        #expect(result.mesh.vertexCount == 6)
        #expect(result.report.weldedVertices == 2)
        #expect(result.report.partsUsed == 2)
        #expect(result.report.facesIn == 4)
        #expect(result.mesh.boundingBox == Box(minimum: Vec3(0, 0, 0), maximum: Vec3(2, 1, 0)))
        // Welded, the shared edge is no longer open: only the outline is.
        #expect(result.mesh.openEdgeCount == 6)
    }

    @Test("with welding off, every piece keeps its own corners")
    func noWelding() {
        let result = MeshAssembly.assemble([square(), square(at: Vec3(1, 0, 0))], weldTolerance: 0)
        #expect(result.mesh.vertexCount == 8)
        #expect(result.report.weldedVertices == 0)
        #expect(result.mesh.openEdgeCount == 8)
    }

    @Test("faces with missing or impossible corners are dropped")
    func invalidFaces() {
        var part = square()
        part.triangles.append(Triangle(0, 1, 9))
        part.vertices.append(Vec3(.nan, 0, 0))
        part.triangles.append(Triangle(0, 1, 4))
        let result = MeshAssembly.assemble([part])
        #expect(result.mesh.faceCount == 2)
        #expect(result.report.invalidFaces == 2)
    }

    @Test("faces with no area are dropped, including ones welding collapses")
    func degenerateFaces() {
        let part = MeshPart(
            vertices: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(2, 0, 0), Vec3(0, 1, 0), Vec3(0.000_1, 1, 0)],
            triangles: [
                Triangle(0, 1, 2),  // three corners in a line
                Triangle(0, 0, 1),  // a repeated corner
                Triangle(0, 1, 3),  // a real face
                Triangle(1, 3, 4),  // corners 3 and 4 are 0.1 mm apart and weld together
            ])
        let result = MeshAssembly.assemble([part])
        #expect(result.mesh.faceCount == 1)
        #expect(result.report.degenerateFaces == 3)
    }

    @Test("a crop box keeps only faces centred inside it")
    func cropping() {
        let crop = Box(minimum: Vec3(-0.5, -0.5, -0.5), maximum: Vec3(1.5, 1.5, 0.5))
        let result = MeshAssembly.assemble([square(), square(at: Vec3(5, 0, 0))], crop: crop)
        #expect(result.mesh.faceCount == 2)
        #expect(result.report.croppedFaces == 2)
        #expect(result.report.partsUsed == 1)
    }

    @Test("no pieces, or empty pieces, give an empty mesh")
    func emptyInput() {
        #expect(MeshAssembly.assemble([]).mesh.isEmpty)
        let result = MeshAssembly.assemble([MeshPart(vertices: [], triangles: [])])
        #expect(result.mesh.isEmpty)
        #expect(result.report.partsUsed == 0)
    }

    @Test("corners too far out to round are kept unwelded rather than lost")
    func hugeCoordinates() {
        let part = MeshPart(
            vertices: [Vec3(1e300, 0, 0), Vec3(1e300, 1e290, 0), Vec3(1e300, 0, 1e290)],
            triangles: [Triangle(0, 1, 2)])
        let result = MeshAssembly.assemble([part])
        #expect(result.mesh.faceCount == 1)
        #expect(result.mesh.vertexCount == 3)
    }

    @Test("the report lists every count for the log")
    func reportDetails() {
        let details = MeshAssembly.assemble([square()]).report.logDetails
        #expect(details["parts"] == "1")
        #expect(details["facesIn"] == "2")
        #expect(details.count == 6)
    }
}

@Suite("Transform from a column-major matrix")
struct ColumnMajorTransformTests {
    @Test("a quarter turn about y with a move reads the right way round")
    func readsColumns() throws {
        // Columns: x axis → (0, 0, -1), y axis → (0, 1, 0), z axis → (1, 0, 0), then
        // a move of (10, 20, 30).
        let values: [Double] = [0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 10, 20, 30, 1]
        let transform = try #require(Transform(columnMajor: values))
        #expect(transform.apply(to: Vec3(1, 0, 0)) == Vec3(10, 20, 29))
        #expect(transform.apply(to: Vec3(0, 0, 1)) == Vec3(11, 20, 30))
        #expect(transform.apply(to: Vec3(0, 1, 0)) == Vec3(10, 21, 30))
    }

    @Test("the wrong count or a non-number is refused")
    func refusesBadInput() {
        #expect(Transform(columnMajor: [1, 0, 0]) == nil)
        var values: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        #expect(Transform(columnMajor: values) == .identity)
        values[5] = .infinity
        #expect(Transform(columnMajor: values) == nil)
    }
}
