import Foundation
import Testing

@testable import ScanLabCore

struct AxisConversionTests {
    @Test func upInAYUpWorldBecomesUpInAZUpWorld() {
        #expect(Vec3(0, 1, 0).yUpToZUp == Vec3(0, 0, 1))
        #expect(Vec3(1, 0, 0).yUpToZUp == Vec3(1, 0, 0))
        #expect(Vec3(0, 0, 1).yUpToZUp == Vec3(0, -1, 0))
    }

    @Test func conversionKeepsSizeAndFaces() throws {
        let mesh = try Mesh(
            vertices: [Vec3(0, 0, 0), Vec3(0.06, 0, 0), Vec3(0, 0.02, 0), Vec3(0, 0, 0.04)],
            triangles: [Triangle(0, 1, 2), Triangle(0, 2, 3)]
        )
        let converted = mesh.convertedFromYUp()
        #expect(converted.triangles == mesh.triangles)
        let box = try #require(converted.boundingBox)
        // 60 mm wide, 40 mm deep (old z), 20 mm tall (old y).
        #expect(abs(box.size.x - 0.06) < 1e-12)
        #expect(abs(box.size.y - 0.04) < 1e-12)
        #expect(abs(box.size.z - 0.02) < 1e-12)
    }

    @Test func faceNormalsTurnWithTheMesh() throws {
        // A face whose outside points up (+y) in the AR world must point up (+z) after.
        let mesh = try Mesh(
            vertices: [Vec3(0, 0, 0), Vec3(0, 0, 1), Vec3(1, 0, 0)],
            triangles: [Triangle(0, 1, 2)]
        )
        #expect(mesh.faceNormal(0) == Vec3(0, 1, 0))
        #expect(mesh.convertedFromYUp().faceNormal(0) == Vec3(0, 0, 1))
    }

    @Test func emptyMeshStaysEmpty() {
        #expect(Mesh.empty.convertedFromYUp().isEmpty)
    }
}
