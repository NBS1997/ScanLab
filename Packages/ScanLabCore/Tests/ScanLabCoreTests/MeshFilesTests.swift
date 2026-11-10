import Foundation
import Testing

@testable import ScanLabCore

@Suite("Mesh file writing")
struct MeshFilesTests {
    @Test("binary STL is exactly 84 + 50 bytes per face", arguments: [0, 1, 3])
    func stlSize(subdivisions: Int) throws {
        let mesh = SampleMeshes.stepBlock(subdivisions: subdivisions)
        let data = try MeshFiles.stlData(for: mesh)
        #expect(data.count == MeshFiles.stlByteCount(faceCount: mesh.faceCount))
        #expect(data.count == 84 + 50 * mesh.faceCount)
        #expect(readUInt32(data, at: 80) == UInt32(mesh.faceCount))
    }

    @Test("an empty mesh gives a header and a zero count")
    func emptyStl() throws {
        let data = try MeshFiles.stlData(for: .empty)
        #expect(data.count == 84)
        #expect(readUInt32(data, at: 80) == 0)
    }

    @Test("the STL header does not start with \"solid\"")
    func stlHeader() throws {
        let data = try MeshFiles.stlData(for: TestMeshes.cube())
        let header = try #require(String(bytes: data.prefix(80), encoding: .ascii))
        #expect(header.hasPrefix("ScanLab"))
        #expect(!header.hasPrefix("solid"))
        #expect(header.contains("millimetres"))
    }

    @Test("STL positions are in millimetres and match the mesh within 0.1%")
    func stlMillimetres() throws {
        let mesh = SampleMeshes.stepBlock(subdivisions: 1)
        let data = try MeshFiles.stlData(for: mesh)
        var points: [Vec3] = []
        for face in 0..<mesh.faceCount {
            let start = 84 + 50 * face + 12
            for corner in 0..<3 {
                let offset = start + 12 * corner
                let x = Double(readFloat(data, at: offset))
                let y = Double(readFloat(data, at: offset + 4))
                let z = Double(readFloat(data, at: offset + 8))
                points.append(Vec3(x, y, z))
            }
        }
        let box = try #require(Box(enclosing: points))
        let expected = SampleMeshes.stepBlockSize * 1000
        #expect(isClose(box.size, expected, tolerance: expected.z * 0.001))
        #expect(isClose(box.size, Vec3(60, 40, 20), tolerance: 0.001))
    }

    @Test("STL normals have length 1")
    func stlNormals() throws {
        let data = try MeshFiles.stlData(for: TestMeshes.cube())
        let x = Double(readFloat(data, at: 84))
        let y = Double(readFloat(data, at: 88))
        let z = Double(readFloat(data, at: 92))
        let normal = Vec3(x, y, z)
        #expect(isClose(normal.length, 1, tolerance: 1e-6))
    }

    @Test("OBJ text is in millimetres with faces counted from 1")
    func objText() throws {
        let mesh = try Mesh(vertices: [.zero, Vec3(0.06, 0, 0), Vec3(0, 0.0125, 0)], triangles: [Triangle(0, 1, 2)])
        let text = MeshFiles.objText(for: mesh)
        #expect(text.hasPrefix("# ScanLab OBJ, units: millimetres\n"))
        #expect(text.contains("\nv 0 0 0\n"))
        #expect(text.contains("\nv 60 0 0\n"))
        #expect(text.contains("\nv 0 12.5 0\n"))
        #expect(text.hasSuffix("\nf 1 2 3\n"))
    }

    @Test("OBJ written in millimetres reads back to the same mesh within 0.1%")
    func objRoundTrip() throws {
        let mesh = SampleMeshes.stepBlock(subdivisions: 1)
        let text = MeshFiles.objText(for: mesh)
        let back = try MeshFiles.parseOBJ(text, unit: .millimetres)
        #expect(back.triangles == mesh.triangles)
        #expect(back.vertexCount == mesh.vertexCount)
        for (original, read) in zip(mesh.vertices, back.vertices) {
            #expect(isClose(original, read, tolerance: 1e-7))
        }
        let box = try #require(back.boundingBox)
        #expect(isClose(box.size, SampleMeshes.stepBlockSize, tolerance: SampleMeshes.stepBlockSize.z * 0.001))
    }

    @Test("writing to a file and reading it back", arguments: MeshFormat.allCases)
    func fileRoundTrip(format: MeshFormat) throws {
        let folder = try TestMeshes.temporaryFolder()
        defer { TestMeshes.cleanUp(folder) }
        let url = folder.appending(path: "cube.\(format.fileExtension)")
        let mesh = TestMeshes.cube(size: 0.05)
        try MeshFiles.write(mesh, as: format, to: url)
        let written = try Data(contentsOf: url)
        let expected = try MeshFiles.data(for: mesh, as: format)
        #expect(written == expected)
        if format == .obj {
            let back = try MeshFiles.read(from: url, unit: .millimetres)
            #expect(isClose(back.volume, mesh.volume, tolerance: 1e-12))
        }
    }

    @Test("writing into a folder that does not exist fails with a reason")
    func missingFolder() throws {
        let folder = try TestMeshes.temporaryFolder()
        defer { TestMeshes.cleanUp(folder) }
        let url = folder.appending(path: "no-such-folder/cube.stl")
        let error = #expect(throws: MeshFileError.self) {
            try MeshFiles.write(TestMeshes.cube(), as: .stl, to: url)
        }
        guard case .writeFailed(let reason) = error else {
            Issue.record("expected a write failure, got \(String(describing: error))")
            return
        }
        #expect(!reason.isEmpty)
    }

    @Test("too little free space fails before writing, leaving no file")
    func noSpace() throws {
        let folder = try TestMeshes.temporaryFolder()
        defer { TestMeshes.cleanUp(folder) }
        let url = folder.appending(path: "cube.stl")
        let data = try MeshFiles.stlData(for: TestMeshes.cube())
        #expect(throws: MeshFileError.noSpace) {
            try MeshFiles.write(data, to: url, availableCapacity: 1_000)
        }
        #expect(!FileManager.default.fileExists(atPath: url.path()))
        try MeshFiles.write(data, to: url, availableCapacity: 10_000_000_000)
        #expect(FileManager.default.fileExists(atPath: url.path()))
    }

    @Test("storage-full errors are recognised in their different forms")
    func classify() {
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: [NSUnderlyingErrorKey: posix])
        let other = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        #expect(MeshFiles.classify(cocoa) == .noSpace)
        #expect(MeshFiles.classify(posix) == .noSpace)
        #expect(MeshFiles.classify(wrapped) == .noSpace)
        #expect(MeshFiles.classify(MeshFileError.tooLarge(faces: 5)) == .tooLarge(faces: 5))
        #expect(MeshFiles.classify(other) != .noSpace)
    }

    @Test("numbers are written plainly with up to four decimals")
    func numbers() {
        #expect(MeshFiles.formatNumber(60) == "60")
        #expect(MeshFiles.formatNumber(12.5) == "12.5")
        #expect(MeshFiles.formatNumber(-0.0001) == "-0.0001")
        #expect(MeshFiles.formatNumber(1.23456) == "1.2346")
        #expect(MeshFiles.formatNumber(-3.05) == "-3.05")
        #expect(MeshFiles.formatNumber(0.00004) == "0")
        #expect(MeshFiles.formatNumber(-0.00004) == "0")
        #expect(MeshFiles.formatNumber(.infinity) == "inf")
    }

    @Test("formats and units describe themselves")
    func formats() {
        #expect(MeshFormat.allCases.map(\.displayName) == ["STL", "OBJ"])
        #expect(MeshFormat.obj.id == "obj")
        #expect(FileUnit.metres.metresPerUnit == 1)
        #expect(FileUnit.millimetres.metresPerUnit == 0.001)
    }

    @Test("every file error explains itself")
    func errorText() {
        let errors: [MeshFileError] = [
            .noSpace, .writeFailed("disk"), .readFailed("gone"),
            .malformed(line: 3, reason: "bad"), .tooLarge(faces: 9),
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
        #expect(MeshFileError.malformed(line: 3, reason: "bad").localizedDescription.contains("Line 3"))
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let bytes = [UInt8](data[offset..<(offset + 4)])
        var value: UInt32 = 0
        for (position, byte) in bytes.enumerated() {
            value |= UInt32(byte) << UInt32(8 * position)
        }
        return value
    }

    private func readFloat(_ data: Data, at offset: Int) -> Float {
        Float(bitPattern: readUInt32(data, at: offset))
    }
}
