import Foundation
import Testing

@testable import ScanLabCore

/// Regression tests for build 4, where a saved sweep opened as "This scan could not be
/// found": file checks were given "%20" in place of the space in "Application Support".
@Suite("File system paths")
struct FileSystemPathTests {
    /// A folder whose name has a space, like the phone's "Application Support".
    private func folderWithSpace() throws -> URL {
        let parent = try TestMeshes.temporaryFolder()
        let folder = parent.appending(path: "Application Support", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("keeps spaces as spaces, so FileManager finds the folder")
    func spacesKept() throws {
        let folder = try folderWithSpace()
        #expect(folder.fileSystemPath.hasSuffix("Application Support/"))
        #expect(!folder.fileSystemPath.contains("%20"))
        #expect(FileManager.default.fileExists(atPath: folder.fileSystemPath))
    }

    @Test("other characters are not escaped either")
    func otherCharacters() {
        let url = URL(filePath: "/tmp/Scan #1 (naïve)/model.obj")
        #expect(url.fileSystemPath == "/tmp/Scan #1 (naïve)/model.obj")
    }

    @Test("unfinished photo captures are found inside a folder with a space")
    func unfinishedCapturesFound() throws {
        let parent = try folderWithSpace()
        let folders = RawCaptureFolders.new(in: parent)
        try FileManager.default.createDirectory(at: folders.images, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: folders.images.appending(path: "IMG_0001.HEIC"))
        let found = RawCaptureFiles.unfinished(in: parent)
        #expect(found.count == 1)
        #expect(found.first?.images == 1)
    }

    @Test("a capture inside a folder with a space can be discarded")
    func discardWorks() throws {
        let parent = try folderWithSpace()
        let folders = RawCaptureFolders.new(in: parent)
        try FileManager.default.createDirectory(at: folders.images, withIntermediateDirectories: true)
        try RawCaptureFiles.discard(folders)
        #expect(!FileManager.default.fileExists(atPath: folders.root.fileSystemPath))
    }

    @Test("the built model is found inside a folder with a space")
    func modelFileFound() throws {
        let parent = try folderWithSpace()
        try Data("v 0 0 0\n".utf8).write(to: parent.appending(path: "baked_mesh.obj"))
        #expect(PhotoModelImport.modelFile(in: parent)?.lastPathComponent == "baked_mesh.obj")
    }
}
