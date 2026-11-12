import ARKit
import AVFoundation
import Foundation
import Metal
import RealityKit
import ScanLabCore
import UIKit

/// The real sweep capture (U07, ADR-005): an ARKit world-tracking session with scene
/// reconstruction, behind Core's `SweepCapturing` port.
///
/// How the pieces fit:
/// - **The camera view** is RealityKit's `ARView` with its "show scene understanding"
///   option, which draws the reconstructed surface as a coloured wireframe over the
///   camera picture as it grows. RealityKit is Apple's current framework for camera
///   AR on iOS; the SceneKit view used by Explore (`ARSCNView`) belongs to SceneKit,
///   which Apple has deprecated as of iOS 26. Drawing the mesh ourselves in SceneKit
///   would also mean rebuilding geometry on every update; RealityKit does it for free.
/// - **The surface** arrives as "mesh anchors": the platform splits the world into
///   blocks about a metre across, each with its own small mesh, and keeps refining
///   them while the phone moves. `SweepReceiver` keeps the latest version of each on a
///   private background queue and reports counts to the screen.
/// - **The detailed model** (U14, ADR-029) comes from the LiDAR's own depth pictures,
///   not from that coarse room-scale surface. While tracking is normal, each depth
///   picture, with the camera's position and lens numbers, is handed to a
///   `FusionWorker`, which fuses it into Core's `DepthFusion` grid in the background.
/// - **Finish** pauses the session, merges the platform's pieces with Core's
///   `MeshAssembly` (kept as a fallback), then asks the worker to draw the fused
///   surface. The fused model is returned unless fusion produced nothing (DF-7). Both
///   are y-up metres; `SweepCaptureService` turns the result z-up and saves it.
@MainActor
final class ARKitSweepCapture: LiveSweepCapturing {
    private let receiver: SweepReceiver
    private let log: any Logging
    private var view: ARView?
    private var isRunning = false

    init(log: any Logging) {
        self.log = log
        receiver = SweepReceiver(log: log)
    }

    func start() -> SweepStreams {
        if isRunning {
            cancel()
        }
        let (progress, progressContinuation) = AsyncStream.makeStream(
            of: SweepProgress.self, bufferingPolicy: .bufferingNewest(1))
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        let streams = SweepStreams(progress: progress, statuses: statuses)

        guard ARWorldTrackingConfiguration.isSupported,
            ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        else {
            log.error("capture", "Sweep unsupported", ["reason": "scene reconstruction is not supported"])
            statusContinuation.yield(
                .unsupported(reason: "This phone has no LiDAR scanner, so sweep capture cannot run."))
            statusContinuation.finish()
            progressContinuation.finish()
            return streams
        }

        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .denied || permission == .restricted {
            log.warning("capture", "Camera permission denied", ["status": String(describing: permission.rawValue)])
            statusContinuation.yield(.permissionDenied)
            statusContinuation.finish()
            progressContinuation.finish()
            return streams
        }

        let configuration = ARWorldTrackingConfiguration()
        // `.mesh` builds triangles only; `.meshWithClassification` would also label
        // each face (wall, floor, seat…), which a scan of one subject does not need.
        configuration.sceneReconstruction = .mesh
        // Gravity is the platform's y axis, so "up" in the scan is truly up.
        configuration.worldAlignment = .gravity
        // Depth pictures for fusion (U14). Every LiDAR phone supports this; if not, the
        // sweep still works and falls back to the scene mesh (DF-7).
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        } else {
            log.warning("capture", "Depth pictures unsupported", ["fallback": "scene mesh"])
        }
        let session = cameraView().session
        session.delegate = receiver
        session.delegateQueue = receiver.queue
        receiver.begin(progress: progressContinuation, statuses: statusContinuation)
        statusContinuation.yield(.starting)
        // If the owner has not yet been asked, ARKit asks for camera permission here.
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
        isRunning = true
        log.info("capture", "Sweep session started", ["reconstruction": "mesh", "fusion": "depth pictures"])
        return streams
    }

    func finish() async throws -> Mesh {
        guard isRunning, let session = view?.session else { return .empty }
        isRunning = false
        // Pausing first means no anchor changes while the copy below is made.
        session.pause()
        let assembled = await receiver.assemble()
        log.info("capture", "Sweep mesh assembled", assembled.report.logDetails)
        let outcome = await receiver.finishFusion()
        log.info("capture", "Fusion finished", outcome.logDetails)
        let sceneFaces = String(assembled.mesh.faceCount)
        guard !outcome.fused.mesh.isEmpty else {
            log.warning(
                "capture", "Sweep model chosen",
                ["source": "scene mesh", "reason": "fusion produced no surface", "faces": sceneFaces])
            return assembled.mesh
        }
        let fusedFaces = String(outcome.fused.mesh.faceCount)
        log.info(
            "capture", "Sweep model chosen",
            ["source": "depth fusion", "faces": fusedFaces, "scene mesh faces": sceneFaces])
        return outcome.fused.mesh
    }

    func cancel() {
        guard isRunning else { return }
        isRunning = false
        view?.session.pause()
        receiver.discard()
    }

    func makeCameraView() -> UIView {
        cameraView()
    }

    /// One `ARView` for the app's lifetime, made the first time it is needed. It owns
    /// the session, so the view and the capture always share it.
    private func cameraView() -> ARView {
        if let view {
            return view
        }
        let made = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        // Draws the reconstructed surface over the camera picture as it grows.
        made.debugOptions.insert(.showSceneUnderstanding)
        made.renderOptions.insert(.disableMotionBlur)
        made.backgroundColor = .black
        view = made
        return made
    }
}

/// Receives ARKit's callbacks on its own serial queue, keeps the latest mesh anchors and
/// turns them into Core values.
///
/// `@unchecked Sendable` is safe because every stored variable below is read and
/// written only on `queue`: ARKit calls the delegate methods there, and `begin`,
/// `discard` and `assemble` hop onto it before touching anything.
final class SweepReceiver: NSObject, @unchecked Sendable {
    /// Progress is sent at most this often, so the screen is not redrawn needlessly.
    static let progressInterval: TimeInterval = 0.25

    let queue = DispatchQueue(label: "com.nbs1997.scanlab.sweep", qos: .userInitiated)
    private let log: any Logging

    private var progress: AsyncStream<SweepProgress>.Continuation?
    private var statuses: AsyncStream<SensorStatus>.Continuation?
    private var anchors: [UUID: ARMeshAnchor] = [:]
    private var faceCount = 0
    private var tracking = SweepTracking.limited(.initialising)
    private var startTime: TimeInterval?
    private var lastSent: TimeInterval = -.infinity
    private var hasReportedRunning = false

    // Fusion (U14). Only touched on `queue`, like everything above.
    private let fusion = FusionWorker()
    private var fusionBusy = false
    private var fusedFrames = 0
    private var skippedFrames = 0
    private var fusionFull = false

    init(log: any Logging) {
        self.log = log
    }

    func begin(
        progress: AsyncStream<SweepProgress>.Continuation, statuses: AsyncStream<SensorStatus>.Continuation
    ) {
        queue.async { [self] in
            endStreams()
            self.progress = progress
            self.statuses = statuses
            anchors = [:]
            faceCount = 0
            tracking = .limited(.initialising)
            startTime = nil
            lastSent = -.infinity
            hasReportedRunning = false
            fusion.reset()
            fusionBusy = false
            fusedFrames = 0
            skippedFrames = 0
            fusionFull = false
            log.info("capture", "Fusion started", FusionSettings.standard.logDetails)
        }
    }

    /// Throws away everything captured and ends the streams.
    func discard() {
        queue.async { [self] in
            log.info("capture", "Sweep session stopped", ["anchors": String(anchors.count), "kept": "no"])
            anchors = [:]
            fusion.reset()
            endStreams()
        }
    }

    /// Copies every anchor's surface and merges them into one mesh, then forgets the
    /// anchors and ends the streams.
    func assemble() async -> AssembledMesh {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let parts = anchors.values.compactMap(Self.part(from:))
                let assembled = MeshAssembly.assemble(parts)
                log.info("capture", "Sweep session stopped", ["anchors": String(anchors.count), "kept": "yes"])
                anchors = [:]
                endStreams()
                continuation.resume(returning: assembled)
            }
        }
    }

    /// Draws the fused surface once every picture handed over has been fused, and adds
    /// how many pictures were skipped.
    func finishFusion() async -> FusionWorker.Outcome {
        let skipped = await withCheckedContinuation { continuation in
            queue.async { [self] in continuation.resume(returning: skippedFrames) }
        }
        var outcome = await fusion.finish()
        outcome.skippedPictures = skipped
        return outcome
    }

    private func endStreams() {
        statuses?.yield(.stopped)
        statuses?.finish()
        progress?.finish()
        statuses = nil
        progress = nil
    }

    private func anchorsChanged(_ changed: [ARAnchor], removed: Bool) {
        for case let anchor as ARMeshAnchor in changed {
            anchors[anchor.identifier] = removed ? nil : anchor
        }
        faceCount = anchors.values.reduce(0) { $0 + $1.geometry.faces.count }
        sendProgress(force: false)
    }

    private func sendProgress(force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastSent >= Self.progressInterval else { return }
        lastSent = now
        let elapsed = startTime.map { now - $0 } ?? 0
        progress?.yield(
            SweepProgress(
                anchorCount: anchors.count, faceCount: faceCount, elapsed: elapsed, tracking: tracking,
                fusedFrames: fusedFrames, fusionFull: fusionFull))
    }

    // MARK: - Feeding fusion (U14)

    /// Hands one depth picture to the fusion worker, unless tracking is unsure (the
    /// camera position would be wrong) or the last picture is still being fused (DF-5).
    private func feedFusion(_ frame: ARFrame) {
        guard progress != nil, case .normal = frame.camera.trackingState else { return }
        guard !fusionBusy else {
            skippedFrames += 1
            return
        }
        // Copied now, so the frame itself is not kept: holding frames stalls the camera.
        guard let picture = Self.fusionFrame(from: frame) else { return }
        fusionBusy = true
        fusion.integrate(picture) { [weak self] stats in
            self?.queue.async { self?.pictureFused(stats) }
        }
    }

    private func pictureFused(_ stats: FusionStats) {
        fusionBusy = false
        fusedFrames = stats.framesFused
        if stats.isFull && !fusionFull {
            fusionFull = true
            let details = ["blocks": String(stats.blocks), "pictures": String(stats.framesFused)]
            log.warning("capture", "Fusion memory full", details)
        }
        sendProgress(force: false)
    }

    static func tracking(for state: ARCamera.TrackingState) -> SweepTracking {
        switch state {
        case .normal:
            return .normal
        case .notAvailable:
            return .notAvailable
        case .limited(let reason):
            switch reason {
            case .initializing: return .limited(.initialising)
            case .excessiveMotion: return .limited(.movingTooFast)
            case .insufficientFeatures: return .limited(.tooLittleDetail)
            case .relocalizing: return .limited(.relocalising)
            @unknown default: return .limited(.other)
            }
        @unknown default:
            return .limited(.other)
        }
    }
}

extension SweepReceiver: ARSessionDelegate {
    // These methods run on `queue` (the session's delegate queue). They are marked
    // `nonisolated` so Swift does not assume they run on the main thread.

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Every frame's depth picture may be fused; the frame itself is not kept.
        feedFusion(frame)
        // The first frame also means the camera is running.
        guard !hasReportedRunning, progress != nil else { return }
        hasReportedRunning = true
        startTime = ProcessInfo.processInfo.systemUptime
        statuses?.yield(.running)
        log.info("capture", "First frame received")
        sendProgress(force: true)
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchorsChanged(anchors, removed: false)
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        anchorsChanged(anchors, removed: false)
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        anchorsChanged(anchors, removed: true)
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let next = Self.tracking(for: camera.trackingState)
        guard next != tracking else { return }
        tracking = next
        log.info("capture", "Tracking changed", ["state": next.logName])
        sendProgress(force: true)
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        if let arError = error as? ARError, arError.code == .cameraUnauthorized {
            log.warning("capture", "Camera permission denied", ["status": "refused when asked"])
            statuses?.yield(.permissionDenied)
        } else {
            log.error("capture", "Sweep session failed", ["reason": error.localizedDescription])
            statuses?.yield(.failed(reason: error.localizedDescription))
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        log.warning("capture", "Sweep session interrupted")
        statuses?.yield(.interrupted)
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        log.info("capture", "Sweep session resumed")
        statuses?.yield(.running)
    }
}
