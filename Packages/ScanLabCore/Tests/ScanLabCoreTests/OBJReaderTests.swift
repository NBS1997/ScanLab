import Foundation
import Testing

@testable import ScanLabCore

@Suite("OBJ reading")
struct OBJReaderTests {
    @Test("positions are read in metres by default and faces count from 1")
    func basic() throws {
        let mesh = try MeshFiles.parseOBJ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n")
        #expect(mesh.vertices == [.zero, Vec3(1, 0, 0), Vec3(0, 1, 0)])
        #expect(mesh.triangles == [Triangle(0, 1, 2)])
    }

    @Test("millimetre files are converted to metres")
    func millimetres() throws {
        let mesh = try MeshFiles.parseOBJ("v 60 40 20\nv 0 0 0\nv 1 0 0\nf 1 2 3", unit: .millimetres)
        #expect(isClose(mesh.vertices[0], Vec3(0.06, 0.04, 0.02)))
    }

    @Test("a four-cornered face becomes two triangles")
    func quads() throws {
        let mesh = try MeshFiles.parseOBJ("v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n")
        #expect(mesh.triangles == [Triangle(0, 1, 2), Triangle(0, 2, 3)])
    }

    @Test("texture and normal numbers, negative numbers, comments and other lines are handled")
    func variants() throws {
        let text = """
            # made by a test
            mtllib model.mtl
            o Part
            v 0 0 0 1.0
            v 1 0 0
            v 0 1 0 # a trailing comment
            vt 0 0
            vn 0 0 1
            usemtl grey
            f 1/1/1 2/1/1 3/1/1
            f 1//1 2//1 3//1
            f -3 -2 -1

            """
        let mesh = try MeshFiles.parseOBJ(text)
        #expect(mesh.vertexCount == 3)
        #expect(mesh.triangles == Array(repeating: Triangle(0, 1, 2), count: 3))
    }

    @Test("Windows line endings are accepted")
    func windowsLineEndings() throws {
        let mesh = try MeshFiles.parseOBJ("v 0 0 0\r\nv 1 0 0\r\nv 0 1 0\r\nf 1 2 3\r\n")
        #expect(mesh.faceCount == 1)
    }

    @Test("an empty file is an empty mesh")
    func emptyText() throws {
        #expect(try MeshFiles.parseOBJ("") == .empty)
    }

    @Test(
        "malformed lines are reported with their line number",
        arguments: [
            ("v 0 0 0\nv 1 zero 0\n", 2),
            ("v 0 0\n", 1),
            ("v 0 0 0\nv 1 0 0\nf 1 2\n", 3),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 0 1 2\n", 4),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 9\n", 4),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 x\n", 4),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf -4 1 2\n", 4),
            ("v 1e400 0 0\n", 1),
        ])
    func malformed(text: String, line: Int) {
        let error = #expect(throws: MeshFileError.self) {
            try MeshFiles.parseOBJ(text)
        }
        guard case .malformed(let reported, let reason) = error else {
            Issue.record("expected a malformed-line error, got \(String(describing: error))")
            return
        }
        #expect(reported == line)
        #expect(!reason.isEmpty)
    }

    @Test("a file that cannot be opened is reported")
    func missingFile() {
        let url = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).obj")
        let error = #expect(throws: MeshFileError.self) {
            try MeshFiles.read(from: url)
        }
        guard case .readFailed = error else {
            Issue.record("expected a read failure, got \(String(describing: error))")
            return
        }
    }
}
