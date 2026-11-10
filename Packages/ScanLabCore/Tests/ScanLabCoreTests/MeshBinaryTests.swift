import Foundation
import Testing

@testable import ScanLabCore

@Suite("Stored model file")
struct MeshBinaryTests {
    @Test("a model reads back exactly, bit for bit")
    func exactRoundTrip() throws {
        // Awkward numbers that text formats would round.
        let mesh = try Mesh(
            vertices: [Vec3(0.1, 1.0 / 3.0, -2e-7), Vec3(.pi, -0.0, 123_456.789_012_345), Vec3(1e-300, 5, 6)],
            triangles: [Triangle(0, 1, 2), Triangle(2, 1, 0)])
        let data = try MeshBinary.encode(mesh)
        #expect(data.count == MeshBinary.byteCount(vertices: 3, faces: 2))
        let decoded = try MeshBinary.decode(data)
        #expect(decoded == mesh)
        #expect(decoded.vertices[1].y.sign == .minus)
    }

    @Test("the sample model round-trips")
    func sampleRoundTrip() throws {
        let mesh = SampleMeshes.stepBlock(subdivisions: 1)
        #expect(try MeshBinary.decode(try MeshBinary.encode(mesh)) == mesh)
    }

    @Test("an empty model round-trips to a 16-byte file")
    func emptyRoundTrip() throws {
        let data = try MeshBinary.encode(.empty)
        #expect(data.count == 16)
        #expect(try MeshBinary.decode(data) == .empty)
    }

    @Test("the file starts with its name")
    func header() throws {
        let data = try MeshBinary.encode(TestMeshes.cube())
        #expect(String(bytes: data.prefix(8), encoding: .ascii) == "SLMESH01")
    }

    @Test("a cut-short file is reported as incomplete")
    func truncated() throws {
        let data = try MeshBinary.encode(TestMeshes.cube())
        #expect(throws: StoreError.corrupt("the model file is incomplete")) {
            try MeshBinary.decode(data.dropLast(5))
        }
    }

    @Test("a file of another kind is refused", arguments: [Data(), Data("solid cube".utf8), Data(count: 40)])
    func wrongKind(data: Data) {
        #expect(throws: StoreError.corrupt("the model file is not a ScanLab model")) {
            try MeshBinary.decode(data)
        }
    }

    @Test("a face pointing at a missing point is refused")
    func badIndex() throws {
        var bytes = [UInt8](try MeshBinary.encode(TestMeshes.cube()))
        // The first face's first corner is just after the header and the eight points.
        let offset = 16 + 24 * 8
        bytes[offset] = 200
        #expect(throws: StoreError.self) {
            try MeshBinary.decode(Data(bytes))
        }
    }

    @Test("decoding works on a slice that does not start at zero")
    func slice() throws {
        let data = try MeshBinary.encode(TestMeshes.cube())
        let padded = Data([1, 2, 3]) + data
        #expect(try MeshBinary.decode(padded.dropFirst(3)) == TestMeshes.cube())
    }
}
