import AVFoundation
import Foundation
import ModelIO
import RealityKit
import ScanLabCore
import SwiftUI

/// The `PhotoCapturing` adapter (components.md; ADR-006): Apple's Object Capture
/// builds the model on the phone with `PhotogrammetrySession`.
///
/// API names were checked against Apple's documentation on 2026-11-11. On iPhone the
/// only detail level is `.reduced`. The model is requested as OBJ by giving the session
/// a folder instead of a `.usdz` file name (documented for `modelFile(url:detail:)`).
/// If the OBJ request fails, the build is repeated once as USDZ (reusing the saved
/// checkpoint, so it is quicker) and converted to OBJ on the phone with Model I/O.
/// Either way Core's OBJ reader then turns it into a `Mesh`.
///
/// The adapter makes no decisions beyond translating platform messages into Core's
/// events and errors; the state rules live in Core's `PhotoCaptureFlow`.
///
/// SwiftUI is imported because `ObjectCaptureSession` lives in the part of RealityKit
/// that is only available alongside SwiftUI.
struct ObjectCapturePhotoCapture: PhotoCapturing {
    let log: any Logging

    var detailLevel: PhotoDetailLevel { .reduced }

    /// Where capture folders are made: Application Support/PhotoCaptures, on the same
    /// storage as the scans, so keeping a raw capture is a quick move, not a copy.
    /// Unlike the temporary folder, the system never empties it, so photographs
    /// survive the app being closed mid-build (FR-4.3).
    static func standardDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "PhotoCaptures", directoryHint: .isDirectory)
    }

    func prepare() async throws {
        // The capture session's check must run on the main thread.
        let captureSupported = await MainActor.run { ObjectCaptureSession.isSupported }
        let buildSupported = PhotogrammetrySession.isSupported
        guard captureSupported && buildSupported else {
            log.error(
                "photo", "Photo capture unsupported",
                ["capture": String(captureSupported), "build": String(buildSupported)])
            throw PhotoCaptureError.unsupportedDevice
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            log.info("photo", "Camera permission asked", ["granted": String(granted)])
            if !granted { throw PhotoCaptureError.cameraDenied }
        default:
            log.warning("photo", "Camera permission refused", ["status": String(status.rawValue)])
            throw PhotoCaptureError.cameraDenied
        }
    }

    func build(_ capture: RawCaptureFolders) -> AsyncThrowingStream<PhotoBuildEvent, any Error> {
        let log = log
        return AsyncThrowingStream { continuation in
            // The build runs on a background thread. When whoever reads the stream
            // stops (the screen cancelled, or closed), `onTermination` cancels this
            // task, which in turn cancels the platform session (see `runSession`).
            let task = Task.detached(priority: .userInitiated) {
                do {
                    let result = try await Self.run(capture, log: log) { continuation.yield($0) }
                    continuation.yield(.built(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.translate(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Building

    /// Builds as OBJ, falling back to USDZ plus Model I/O once if the OBJ request fails.
    private static func run(
        _ capture: RawCaptureFolders, log: any Logging, emit: @escaping @Sendable (PhotoBuildEvent) -> Void
    ) async throws -> PhotoBuildResult {
        let started = Date()
        // Start from an empty Model folder, so a file left by an earlier attempt can
        // never be mistaken for this build's result.
        let manager = FileManager.default
        if manager.fileExists(atPath: capture.model.fileSystemPath) {
            try manager.removeItem(at: capture.model)
        }
        try manager.createDirectory(at: capture.model, withIntermediateDirectories: true)
        log.info("photo", "Build started", ["capture": shortID(capture), "detail": "reduced"])

        let first = try await runSession(capture, model: capture.model, log: log, emit: emit)
        var route = "obj"
        var poses = first.poses
        var modelFile = PhotoModelImport.modelFile(in: capture.model)
        if modelFile == nil {
            let reason = first.modelError.map(describe) ?? "no OBJ file was written"
            log.warning("photo", "OBJ output failed; trying USDZ", ["reason": reason])
            let usdz = capture.model.appending(path: "model.usdz")
            let second = try await runSession(capture, model: usdz, log: log, emit: emit)
            if let error = second.modelError { throw error }
            poses = second.poses ?? poses
            modelFile = try convertToOBJ(usdz, in: capture.model)
            route = "usdz-modelio"
        }
        guard let modelFile else { throw PhotoCaptureError.noModel }

        let positions = try writeCameraPositions(poses, to: capture.cameraPositions, log: log)
        log.info(
            "photo", "Build finished",
            [
                "capture": shortID(capture), "route": route, "positions": String(positions),
                "seconds": String(Int(Date().timeIntervalSince(started))),
            ])
        return PhotoBuildResult(modelFile: modelFile, cameraPositions: positions, route: route)
    }

    /// Runs one photogrammetry session to the end, turning its messages into events.
    private static func runSession(
        _ capture: RawCaptureFolders, model: URL, log: any Logging,
        emit: @escaping @Sendable (PhotoBuildEvent) -> Void
    ) async throws -> SessionOutcome {
        var configuration = PhotogrammetrySession.Configuration()
        // The same checkpoint folder the capture session filled: the build starts from
        // the capture's saved work, and a second build (after a failure, or the
        // fallback) picks up where the last one got to (Apple's documentation).
        configuration.checkpointDirectory = capture.checkpoint
        let session = try PhotogrammetrySession(input: capture.images, configuration: configuration)
        let box = SessionBox(session)
        try session.process(requests: [.modelFile(url: model, detail: .reduced), .poses])

        return try await withTaskCancellationHandler {
            var reader = OutputReader(log: log, emit: emit)
            var outputs = session.outputs.makeAsyncIterator()
            while let output = try await outputs.next() {
                if try reader.read(output) { break }
            }
            if reader.skipped > 0 {
                log.warning("photo", "Photos skipped", ["count": String(reader.skipped)])
            }
            return reader.outcome
        } onCancel: {
            box.session.cancel()
        }
    }

    fileprivate static func isModel(_ request: PhotogrammetrySession.Request) -> Bool {
        if case .modelFile = request { return true }
        return false
    }

    fileprivate static func name(_ request: PhotogrammetrySession.Request) -> String {
        switch request {
        case .modelFile: "model"
        case .poses: "poses"
        default: "other"
        }
    }

    /// The platform's stage names in ScanLab's plain words.
    fileprivate static func stage(_ stage: PhotogrammetrySession.Output.ProcessingStage?) -> BuildStage? {
        switch stage {
        case .preProcessing: .preparing
        case .imageAlignment: .aligningPhotos
        case .pointCloudGeneration: .makingPoints
        case .meshGeneration: .makingMesh
        case .textureMapping: .colouring
        case .optimization: .tidying
        default: nil
        }
    }

    /// Converts the fallback USDZ model to OBJ with Model I/O, which is part of the
    /// system (no third-party code). The OBJ keeps the USDZ's own units, metres for
    /// Object Capture; the on-device checklist checks the size against calipers.
    private static func convertToOBJ(_ usdz: URL, in folder: URL) throws -> URL {
        guard MDLAsset.canImportFileExtension("usdz"), MDLAsset.canExportFileExtension("obj") else {
            throw PhotoCaptureError.buildFailed("this phone cannot convert the model to OBJ")
        }
        let asset = MDLAsset(url: usdz)
        let obj = folder.appending(path: "model.obj")
        do {
            try asset.export(to: obj)
        } catch {
            throw PhotoCaptureError.buildFailed("the model could not be converted to OBJ (\(describe(error)))")
        }
        return obj
    }

    /// Writes `camera-positions.csv` from the platform's estimate of where each photo
    /// was taken (FR-7.5). Returns how many rows were written; zero when the platform
    /// gave no positions, which is logged but does not stop the scan being saved.
    private static func writeCameraPositions(
        _ poses: PhotogrammetrySession.Poses?, to url: URL, log: any Logging
    ) throws -> Int {
        guard let poses else {
            log.warning("photo", "No camera positions from the build")
            return 0
        }
        var rows: [CameraPosition] = []
        for (sample, pose) in poses.posesBySample {
            let place = pose.translation
            let turn = pose.rotation
            // The pinhole matrix stores the focal lengths on the diagonal and the
            // picture centre in the last column.
            var lens: CameraIntrinsics?
            if let matrix = pose.intrinsics {
                let focal = (x: Double(matrix.columns.0.x), y: Double(matrix.columns.1.y))
                let centre = (x: Double(matrix.columns.2.x), y: Double(matrix.columns.2.y))
                lens = CameraIntrinsics(focalX: focal.x, focalY: focal.y, centreX: centre.x, centreY: centre.y)
            }
            let position = Vec3(Double(place.x), Double(place.y), Double(place.z))
            let imag = turn.imag
            let real = Double(turn.real)
            let rotation = Quaternion(x: Double(imag.x), y: Double(imag.y), z: Double(imag.z), scalar: real)
            let image = poses.urlsBySample[sample]?.lastPathComponent
            let row = CameraPosition(
                sample: sample, imageName: image, position: position, rotation: rotation, intrinsics: lens)
            rows.append(row)
        }
        do {
            try Data(CameraPositionsFile.csv(rows).utf8).write(to: url, options: .atomic)
        } catch {
            throw PhotoCaptureError.from(error)
        }
        return rows.count
    }

    // MARK: - Errors

    /// Turns platform errors into Core's `PhotoCaptureError`, recognising a full phone.
    static func translate(_ error: any Error) -> PhotoCaptureError {
        if let photoError = error as? PhotoCaptureError { return photoError }
        if error is CancellationError { return .cancelled }
        if let buildError = error as? PhotogrammetrySession.Error {
            switch buildError {
            case .insufficientStorage: return .noSpace
            default: return .buildFailed(describe(buildError))
            }
        }
        if let captureError = error as? ObjectCaptureSession.Error {
            switch captureError {
            case .cancelled: return .cancelled
            case .insufficientStorage: return .noSpace
            default: return .captureFailed(describe(captureError))
            }
        }
        let fileError = PhotoCaptureError.from(error)
        if fileError == .noSpace { return .noSpace }
        return .buildFailed(describe(error))
    }

    static func describe(_ error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    private static func shortID(_ capture: RawCaptureFolders) -> String {
        String(capture.id.prefix(8))
    }
}

/// What one photogrammetry session produced.
private struct SessionOutcome {
    var poses: PhotogrammetrySession.Poses?
    var modelError: (any Error)?
}

/// Lets the cancellation handler (which may run on any thread) reach the session.
/// Marked `@unchecked Sendable` because the only thing done from the other thread
/// is `cancel()`, which Apple documents as a request the session handles itself.
private final class SessionBox: @unchecked Sendable {
    let session: PhotogrammetrySession
    init(_ session: PhotogrammetrySession) { self.session = session }
}

/// Turns the session's messages, one at a time, into Core events and log entries,
/// remembering what the caller needs at the end.
private struct OutputReader {
    private typealias Outer = ObjectCapturePhotoCapture

    let log: any Logging
    let emit: @Sendable (PhotoBuildEvent) -> Void
    var outcome = SessionOutcome()
    var fraction = 0.0
    var skipped = 0

    // Returns true when the session has finished all its requests. One case per
    // platform message, hence the long switch.
    // swiftlint:disable:next cyclomatic_complexity
    mutating func read(_ output: PhotogrammetrySession.Output) throws -> Bool {
        switch output {
        case .inputComplete:
            emit(.photosRead)
        case .invalidSample(let id, let reason):
            skipped += 1
            emit(.photoSkipped(reason: "photo \(id): \(reason)"))
        case .skippedSample(let id):
            skipped += 1
            emit(.photoSkipped(reason: "photo \(id) could not be used"))
        case .automaticDownsampling:
            log.warning("photo", "Photos downsampled by the platform")
        case .requestProgress(let request, let fractionComplete) where Outer.isModel(request):
            fraction = fractionComplete
            emit(.progress(BuildUpdate(fraction: fraction)))
        case .requestProgressInfo(let request, let info) where Outer.isModel(request):
            let stage = Outer.stage(info.processingStage)
            let remaining = info.estimatedRemainingTime
            emit(.progress(BuildUpdate(fraction: fraction, stage: stage, secondsRemaining: remaining)))
        case .requestComplete(let request, let result):
            if case .poses(let poses) = result { outcome.poses = poses }
            log.info("photo", "Build request finished", ["request": Outer.name(request)])
        case .requestError(let request, let error):
            if Outer.isModel(request) { outcome.modelError = error }
            let details = ["request": Outer.name(request), "reason": Outer.describe(error)]
            log.error("photo", "Build request failed", details)
        case .processingComplete:
            return true
        case .processingCancelled:
            throw PhotoCaptureError.cancelled
        case .stitchingIncomplete:
            log.warning("photo", "Not all photos could be joined into one model")
        default:
            // Progress for the camera-positions request, and messages added by
            // later systems: nothing to show.
            break
        }
        return false
    }
}

/// A stand-in for screen previews: never builds anything real.
struct PreviewPhotoCapture: PhotoCapturing {
    var detailLevel: PhotoDetailLevel { .reduced }

    func prepare() async throws {
        throw PhotoCaptureError.unsupportedDevice
    }

    func build(_ capture: RawCaptureFolders) -> AsyncThrowingStream<PhotoBuildEvent, any Error> {
        AsyncThrowingStream { $0.finish(throwing: PhotoCaptureError.unsupportedDevice) }
    }
}
