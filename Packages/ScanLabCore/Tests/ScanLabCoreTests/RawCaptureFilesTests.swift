import Foundation
import Testing

@testable import ScanLabCore

/// Makes a capture folder like Object Capture leaves: photographs, working data and a
/// built model.
private func makeCapture(in parent: URL, images: Int, imageBytes: Int = 1_000) throws -> RawCaptureFolders {
    let folders = RawCaptureFolders.new(in: parent)
    let manager = FileManager.default
    try manager.createDirectory(at: folders.images, withIntermediateDirectories: true)
    try manager.createDirectory(at: folders.checkpoint, withIntermediateDirectories: true)
    try manager.createDirectory(at: folders.model, withIntermediateDirectories: true)
    for index in 0..<images {
        let name = String(format: "IMG_%04d.HEIC", index)
        try Data(repeating: 7, count: imageBytes).write(to: folders.images.appending(path: name))
    }
    try Data(repeating: 1, count: 5_000).write(to: folders.checkpoint.appending(path: "state.bin"))
    try Data("v 0 0 0\n".utf8).write(to: folders.model.appending(path: "baked_mesh.obj"))
    try Data("sample,image\n".utf8).write(to: folders.cameraPositions)
    return folders
}

@Suite("Raw capture files")
struct RawCaptureFilesTests {
    @Test("folder layout")
    func layout() {
        let id = UUID()
        let folders = RawCaptureFolders.new(in: URL(filePath: "/captures"), id: id)
        #expect(folders.id == id.uuidString)
        #expect(folders.images.lastPathComponent == "Images")
        #expect(folders.checkpoint.lastPathComponent == "Checkpoint")
        #expect(folders.model.lastPathComponent == "Model")
        #expect(folders.cameraPositions.lastPathComponent == "camera-positions.csv")
        #expect(folders.readMe.lastPathComponent == "README.txt")
        #expect(folders.images.deletingLastPathComponent().lastPathComponent == id.uuidString)
    }

    @Test("counts photographs, including those in sub-folders, and ignores other files")
    func imageCount() throws {
        let parent = try TestMeshes.temporaryFolder()
        let folders = try makeCapture(in: parent, images: 12)
        let pass = folders.images.appending(path: "Pass2")
        try FileManager.default.createDirectory(at: pass, withIntermediateDirectories: true)
        try Data([1]).write(to: pass.appending(path: "IMG_0100.heic"))
        try Data([1]).write(to: folders.images.appending(path: "notes.txt"))
        #expect(RawCaptureFiles.imageCount(in: folders) == 13)
        #expect(RawCaptureFiles.imageCount(in: RawCaptureFolders.new(in: parent)) == 0)
    }

    @Test("sizes count every file, and a missing folder is zero")
    func sizes() throws {
        let parent = try TestMeshes.temporaryFolder()
        let folders = try makeCapture(in: parent, images: 4, imageBytes: 10_000)
        let images = RawCaptureFiles.bytes(in: folders.images)
        #expect(images >= 40_000)
        #expect(RawCaptureFiles.bytes(in: folders.root) > images)
        #expect(RawCaptureFiles.bytes(in: parent.appending(path: "missing")) == 0)
    }

    @Test("keeping removes working data and the model, adds a README, and keeps photos and positions")
    func prepareForKeeping() throws {
        let parent = try TestMeshes.temporaryFolder()
        let folders = try makeCapture(in: parent, images: 20)
        let bytes = try RawCaptureFiles.prepareForKeeping(folders, detail: .reduced)
        let names = Set(try FileManager.default.contentsOfDirectory(atPath: folders.root.fileSystemPath))
        #expect(names == ["Images", "camera-positions.csv", "README.txt"])
        #expect(RawCaptureFiles.imageCount(in: folders) == 20)
        #expect(bytes == RawCaptureFiles.bytes(in: folders.root))
        let readMe = try String(contentsOf: folders.readMe, encoding: .utf8)
        #expect(readMe.contains("20 photos"))
        #expect(readMe.contains("camera-positions.csv"))
        #expect(readMe.contains("reduced detail"))
    }

    @Test("keeping a folder that does not exist fails with a file error")
    func prepareMissing() throws {
        let parent = try TestMeshes.temporaryFolder()
        let folders = RawCaptureFolders.new(in: parent)
        #expect(throws: PhotoCaptureError.self) {
            try RawCaptureFiles.prepareForKeeping(folders, detail: .reduced)
        }
    }

    @Test("README without camera positions says so")
    func readMeWithoutPositions() {
        let text = RawCaptureFiles.readMe(images: 1, hasPositions: false, detail: .reduced)
        #expect(text.contains("1 photo "))
        #expect(text.contains("No camera positions"))
        #expect(text.hasSuffix("\n"))
    }

    @Test("unfinished captures are listed newest first; empty ones are tidied away")
    func unfinished() throws {
        let parent = try TestMeshes.temporaryFolder()
        let older = try makeCapture(in: parent, images: 15)
        let newer = try makeCapture(in: parent, images: 30)
        defer { TestMeshes.cleanUp(parent) }
        let manager = FileManager.default
        let hourAgo = Date(timeIntervalSinceNow: -3_600)
        try manager.setAttributes([.modificationDate: hourAgo], ofItemAtPath: older.root.fileSystemPath)
        try manager.setAttributes([.modificationDate: Date()], ofItemAtPath: newer.root.fileSystemPath)
        let empty = RawCaptureFolders.new(in: parent)
        try manager.createDirectory(at: empty.images, withIntermediateDirectories: true)
        let other = parent.appending(path: "not-a-capture")
        try manager.createDirectory(at: other, withIntermediateDirectories: true)

        let found = RawCaptureFiles.unfinished(in: parent)
        #expect(found.map(\.images) == [30, 15])
        #expect(found.first?.folders == newer)
        #expect(found.first?.id == newer.id)
        #expect((found.first?.bytes ?? 0) > 0)
        #expect(!manager.fileExists(atPath: empty.root.fileSystemPath))
        #expect(manager.fileExists(atPath: other.fileSystemPath))
    }

    @Test("no parent folder means no unfinished captures")
    func unfinishedMissing() throws {
        let parent = try TestMeshes.temporaryFolder().appending(path: "nothing")
        #expect(RawCaptureFiles.unfinished(in: parent).isEmpty)
    }

    @Test("export names are safe on the phone and on Windows")
    func exportName() {
        #expect(RawCaptureFiles.exportName(for: "Bracket") == "Bracket raw capture.zip")
        #expect(RawCaptureFiles.exportName(for: "  a/b:c  ") == "a-b-c raw capture.zip")
        #expect(RawCaptureFiles.exportName(for: "   ") == "ScanLab raw capture.zip")
    }

    @Test("discard removes the folder, and discarding twice is fine")
    func discard() throws {
        let parent = try TestMeshes.temporaryFolder()
        let folders = try makeCapture(in: parent, images: 3)
        try RawCaptureFiles.discard(folders)
        #expect(!FileManager.default.fileExists(atPath: folders.root.fileSystemPath))
        try RawCaptureFiles.discard(folders)
    }
}
