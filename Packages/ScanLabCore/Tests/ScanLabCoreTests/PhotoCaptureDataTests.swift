import Foundation
import Testing

@testable import ScanLabCore

@Suite("Camera positions file")
struct CameraPositionsTests {
    @Test("rows in photograph order with fixed decimals")
    func csv() {
        let lens = CameraIntrinsics(focalX: 1520.25, focalY: 1520.5, centreX: 960, centreY: 720)
        let positions = [
            CameraPosition(
                sample: 1, imageName: "IMG_0001.HEIC", position: Vec3(0.12, 0.045, -0.01),
                rotation: Quaternion(x: 0, y: 0.707107, z: 0, scalar: 0.707107), intrinsics: lens),
            CameraPosition(sample: 0, imageName: nil, position: .zero, rotation: .identity),
        ]
        let lines = CameraPositionsFile.csv(positions).split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0] == CameraPositionsFile.header)
        #expect(lines[1] == "0,,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,1.000000,,,,")
        let pose = "1,IMG_0001.HEIC,0.120000,0.045000,-0.010000,0.000000,0.707107,0.000000,0.707107"
        let lensText = "1520.250,1520.500,960.000,720.000"
        #expect(lines[2] == pose + "," + lensText)
    }

    @Test("an empty list is just the header")
    func empty() {
        #expect(CameraPositionsFile.csv([]) == CameraPositionsFile.header + "\n")
    }

    @Test("awkward names are quoted and bad numbers left empty")
    func awkward() {
        #expect(CameraPositionsFile.field("a,b") == "\"a,b\"")
        #expect(CameraPositionsFile.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CameraPositionsFile.field("plain.heic") == "plain.heic")
        #expect(CameraPositionsFile.number(.nan, 3) == "")
        #expect(CameraPositionsFile.number(-0.5, 2) == "-0.50")
    }
}

@Suite("Background build observer")
struct BackgroundBuildObserverTests {
    private let left = Date(timeIntervalSince1970: 1_794_405_930)

    @Test("progress that moved while away is reported as carrying on")
    func carriedOn() throws {
        var observer = BackgroundBuildObserver()
        observer.appLeft(at: left, fraction: 0.12)
        #expect(observer.isAway)
        let returned1 = observer.appReturned(at: left.addingTimeInterval(95), fraction: 0.48)
        let seen = try #require(returned1)
        #expect(!observer.isAway)
        #expect(seen.seconds == 95)
        #expect(seen.advanced)
        #expect(seen.summary == "Away 95 s: building carried on (12% → 48%).")
        #expect(seen.logDetails["advanced"] == "true")
        #expect(seen.logDetails["ending"] == "none")
    }

    @Test("no movement is reported as paused")
    func paused() throws {
        var observer = BackgroundBuildObserver()
        observer.appLeft(at: left, fraction: 0.3)
        observer.appLeft(at: left.addingTimeInterval(10), fraction: 0.9)
        let returned2 = observer.appReturned(at: left.addingTimeInterval(40), fraction: 0.3005)
        let seen = try #require(returned2)
        #expect(seen.seconds == 40)
        #expect(!seen.advanced)
        #expect(seen.summary == "Away 40 s: building paused (stayed at 30%).")
    }

    @Test("an ending while away is recorded once")
    func endings() throws {
        var observer = BackgroundBuildObserver()
        observer.buildEnded(.failed)
        let returned3 = observer.appReturned(at: left, fraction: 0)
        #expect(returned3 == nil)
        observer.appLeft(at: left, fraction: 0.5)
        observer.buildEnded(.built)
        observer.buildEnded(.failed)
        let returned4 = observer.appReturned(at: left.addingTimeInterval(5), fraction: 1)
        let built = try #require(returned4)
        #expect(built.ending == .built)
        #expect(built.advanced)
        #expect(built.summary.contains("finished building in the background"))

        observer.appLeft(at: left, fraction: 0.5)
        observer.buildEnded(.failed)
        let returned5 = observer.appReturned(at: left.addingTimeInterval(5), fraction: 0.5)
        let failed = try #require(returned5)
        #expect(failed.summary.contains("building failed in the background (50% → 50%)"))

        observer.appLeft(at: left, fraction: 0.2)
        observer.buildEnded(.cancelled)
        let returned6 = observer.appReturned(at: left.addingTimeInterval(-3), fraction: 0.1)
        let stopped = try #require(returned6)
        #expect(stopped.seconds == 0)
        #expect(stopped.fractionAfter == 0.2)
        #expect(stopped.summary.contains("stopped in the background"))
    }
}

@Suite("Photo model import")
struct PhotoModelImportTests {
    /// An OBJ shaped like Object Capture's output: a material library, texture and
    /// normal numbers, and each corner repeated for two texture patches.
    private let objectCaptureOBJ = """
        # Apple Object Capture
        mtllib baked_mesh.mtl
        usemtl material0
        v 0 0 0
        v 0.06 0 0
        v 0 0.04 0
        v 0.06 0 0
        v 0.06 0.04 0
        v 0 0.04 0
        vt 0 0
        vt 1 0
        vt 0 1
        vn 0 0 1
        f 1/1/1 2/2/1 3/3/1
        f 4/2/1 5/2/1 6/3/1
        """

    @Test("reads metres, joins repeated corners and turns z-up")
    func importModel() throws {
        let folder = try TestMeshes.temporaryFolder()
        defer { TestMeshes.cleanUp(folder) }
        try Data(objectCaptureOBJ.utf8).write(to: folder.appending(path: "baked_mesh.obj"))
        try Data("newmtl material0\n".utf8).write(to: folder.appending(path: "baked_mesh.mtl"))
        let url = try #require(PhotoModelImport.modelFile(in: folder))
        #expect(url.lastPathComponent == "baked_mesh.obj")
        let mesh = try PhotoModelImport.mesh(from: url)
        #expect(mesh.vertexCount == 4)
        #expect(mesh.faceCount == 2)
        let size = try #require(mesh.boundingBox?.size)
        // 60 mm wide, 40 mm tall in y-up becomes 40 mm tall in z.
        #expect(isClose(size, Vec3(0.06, 0, 0.04)))
        #expect(PhotoModelImport.sizeWarning(for: mesh) == nil)
    }

    @Test("no OBJ in the folder, or no folder")
    func noModelFile() throws {
        let folder = try TestMeshes.temporaryFolder()
        defer { TestMeshes.cleanUp(folder) }
        try Data().write(to: folder.appending(path: "model.usdz"))
        #expect(PhotoModelImport.modelFile(in: folder) == nil)
        #expect(PhotoModelImport.modelFile(in: folder.appending(path: "missing")) == nil)
    }

    @Test("a model with no faces is noModel; an unreadable one is buildFailed")
    func badModels() throws {
        let folder = try TestMeshes.temporaryFolder()
        defer { TestMeshes.cleanUp(folder) }
        let empty = folder.appending(path: "empty.obj")
        try Data("v 0 0 0\n".utf8).write(to: empty)
        #expect(throws: PhotoCaptureError.noModel) { try PhotoModelImport.mesh(from: empty) }
        let broken = folder.appending(path: "broken.obj")
        try Data("v 0 0 0\nf 1 2 3\n".utf8).write(to: broken)
        #expect(throws: PhotoCaptureError.self) { try PhotoModelImport.mesh(from: broken) }
        do {
            _ = try PhotoModelImport.mesh(from: folder.appending(path: "missing.obj"))
            Issue.record("expected a failure")
        } catch let error as PhotoCaptureError {
            if case .buildFailed(let reason) = error {
                #expect(reason.contains("could not be read"))
            } else {
                Issue.record("wrong error \(error)")
            }
        }
    }

    @Test("welding drops faces that collapse")
    func weldCollapse() throws {
        let mesh = try Mesh(
            vertices: [.zero, Vec3(1, 0, 0), .zero, Vec3(0, 1, 0)],
            triangles: [Triangle(0, 1, 2), Triangle(0, 1, 3)])
        let welded = PhotoModelImport.welded(mesh)
        #expect(welded.vertexCount == 3)
        #expect(welded.triangles == [Triangle(0, 1, 2)])
    }

    @Test("size warnings for models far too big or too small")
    func sizeWarnings() {
        #expect(PhotoModelImport.sizeWarning(for: .empty) == "the model has no size")
        #expect(PhotoModelImport.sizeWarning(for: TestMeshes.cube(size: 5))?.contains("larger") == true)
        #expect(PhotoModelImport.sizeWarning(for: TestMeshes.cube(size: 0.001))?.contains("smaller") == true)
        #expect(PhotoModelImport.sizeWarning(for: TestMeshes.cube(size: 0.1)) == nil)
    }
}
