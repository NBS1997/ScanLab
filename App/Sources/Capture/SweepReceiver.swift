import ARKit
import Foundation
import ScanLabCore

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

    // Subject box and coverage (U09 part 1). Fusion waits until scanning begins (SB-1).
    let picker: SubjectPicker
    private var scanning = false
    private var dome: CoverageDome?
    private var lastCamera: Vec3?
    private var coverageLogged = 0

    init(log: any Logging) {
        self.log = log
        picker = SubjectPicker(log: log)
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
            scanning = false
            dome = nil
            lastCamera = nil
            coverageLogged = 0
        }
    }

    /// Starts fusing: inside `box` at the finer setting with a coverage dome, or over the
    /// whole view as in build 7 when `box` is nil (SB-1, SB-7).
    func beginScanning(in box: SubjectBox?) {
        queue.async { [self] in
            let settings: FusionSettings = box == nil ? .standard : .boxed
            fusion.reset(settings: settings, region: box?.bounds)
            dome = box.map { CoverageDome(centre: $0.centre) }
            scanning = true
            var details = settings.logDetails
            details["subject"] = box == nil ? "whole scene" : "box"
            for (key, value) in box?.logDetails ?? [:] {
                details[key] = value
            }
            log.info("capture", "Fusion started", details)
            sendProgress(force: true)
        }
    }

    /// Throws away everything captured and ends the streams.
    func discard() {
        queue.async { [self] in
            log.info("capture", "Sweep session stopped", ["anchors": String(anchors.count), "kept": "no"])
            anchors = [:]
            fusion.reset()
            picker.cancel()
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
            queue.async { [self] in
                if let dome {
                    let summary = dome.summary(cameraAt: nil)
                    log.info("capture", "Coverage at finish", ["covered": summary.spoken])
                }
                continuation.resume(returning: skippedFrames)
            }
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
                fusedFrames: fusedFrames, fusionFull: fusionFull, coverage: dome?.summary(cameraAt: lastCamera)))
    }

    // MARK: - Feeding fusion (U14)

    /// Hands one depth picture to the fusion worker, unless tracking is unsure (the
    /// camera position would be wrong) or the last picture is still being fused (DF-5).
    private func feedFusion(_ frame: ARFrame) {
        guard progress != nil, scanning, case .normal = frame.camera.trackingState else { return }
        guard !fusionBusy else {
            skippedFrames += 1
            return
        }
        // Copied now, so the frame itself is not kept: holding frames stalls the camera.
        guard let picture = Self.fusionFrame(from: frame) else { return }
        fusionBusy = true
        if dome != nil {
            dome?.record(picture)
            lastCamera = picture.cameraPosition
            logCoverageMilestones()
        }
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

    /// Logs coverage once at half and once when complete (SB-9).
    private func logCoverageMilestones() {
        guard let summary = dome?.summary(cameraAt: nil) else { return }
        let percent = Int(summary.fraction * 100)
        if percent >= 100, coverageLogged < 100 {
            coverageLogged = 100
            log.info("capture", "Coverage complete", ["pictures": String(fusedFrames)])
        } else if percent >= 50, coverageLogged < 50 {
            coverageLogged = 50
            log.info("capture", "Coverage half way", ["covered": summary.spoken])
        }
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
        // A waiting tap takes what it needs from this frame (SB-2).
        picker.offer(frame)
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
