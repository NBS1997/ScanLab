import ARKit
import AVFoundation
import Foundation
import ScanLabCore
import SceneKit
import UIKit

/// The real live sensor (U06): an ARKit world-tracking session with scene depth
/// (ADR-005), behind Core's `SensorFeeding` port.
///
/// How the pieces fit:
/// - The camera picture is drawn by an `ARSCNView` that shares this session. ARKit
///   draws the picture itself, on the graphics chip, already turned and scaled to fill
///   the view, so ScanLab never copies the full-size camera image. That is the
///   simplest way to keep the view smooth (NFR-7).
/// - ARKit hands each new frame to `FrameReceiver` on a private background queue.
///   The receiver copies the small depth and confidence grids into Core's
///   `DepthFrame` at once and lets the frame go; ARKit reuses a small pool of frames,
///   and holding on to one stalls the camera.
/// - The copied frames travel to the screen through an `AsyncStream`.
@MainActor
final class LiveSensorFeed: LiveCameraFeeding {
    private let session = ARSession()
    private let receiver: FrameReceiver
    private let log: any Logging
    private var isRunning = false

    init(log: any Logging) {
        self.log = log
        receiver = FrameReceiver(log: log)
        // The session keeps only a weak reference to its delegate; `receiver` is kept
        // alive by this object.
        session.delegate = receiver
        session.delegateQueue = receiver.queue
    }

    func start() -> SensorStreams {
        if isRunning {
            stop()
        }
        // Only the newest frame is worth drawing, so older unread frames are dropped.
        let (frames, frameContinuation) = AsyncStream.makeStream(
            of: SensorFrame.self, bufferingPolicy: .bufferingNewest(1))
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        let streams = SensorStreams(frames: frames, statuses: statuses)

        guard ARWorldTrackingConfiguration.isSupported,
            ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        else {
            log.error(
                "sensor", "Live sensor unsupported",
                ["reason": "world tracking with scene depth is not supported on this phone"])
            statusContinuation.yield(
                .unsupported(reason: "This phone does not report LiDAR depth, so the live view cannot run."))
            statusContinuation.finish()
            frameContinuation.finish()
            return streams
        }

        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .denied || permission == .restricted {
            log.warning("sensor", "Camera permission denied", ["status": Self.describe(permission)])
            statusContinuation.yield(.permissionDenied)
            statusContinuation.finish()
            frameContinuation.finish()
            return streams
        }

        let configuration = ARWorldTrackingConfiguration()
        // Scene depth is the raw 256 × 192 depth grid with a confidence value per
        // pixel (V1). The smoothed variant is not used: it blends frames over time,
        // which would hide how noisy the sensor really is, and FR-2.2 asks for the
        // sensor's own reading.
        configuration.frameSemantics = [.sceneDepth]
        receiver.begin(frames: frameContinuation, statuses: statusContinuation)
        statusContinuation.yield(.starting)
        // If the owner has not yet been asked, ARKit asks for camera permission here.
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        log.info(
            "sensor", "Sensor session started",
            ["semantics": "sceneDepth", "cameraPermission": Self.describe(permission)])
        return streams
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        session.pause()
        receiver.end()
    }

    func makeCameraView() -> UIView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = false
        view.rendersCameraGrain = false
        view.backgroundColor = .black
        return view
    }

    private static func describe(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: "authorised"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "not yet asked"
        @unknown default: "unknown"
        }
    }
}

/// Receives ARKit's callbacks on its own serial queue and turns them into Core values.
///
/// `@unchecked Sendable` is safe because every stored variable below is read and
/// written only on `queue`: ARKit calls the delegate methods there, and `begin` and
/// `end` hop onto it before touching anything.
final class FrameReceiver: NSObject, @unchecked Sendable {
    /// How often the measured frame rate is written to the log (NFR-7).
    static let rateLogInterval: TimeInterval = 10

    let queue = DispatchQueue(label: "com.nbs1997.scanlab.sensor", qos: .userInteractive)
    private let log: any Logging

    private var frames: AsyncStream<SensorFrame>.Continuation?
    private var statuses: AsyncStream<SensorStatus>.Continuation?
    private var meter = FrameRateMeter()
    private var frameCount = 0
    private var framesWithoutDepth = 0
    private var firstTimestamp: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var lastRateLog: TimeInterval?
    private var hasReportedRunning = false
    private var lastTracking = ""

    init(log: any Logging) {
        self.log = log
    }

    func begin(
        frames: AsyncStream<SensorFrame>.Continuation, statuses: AsyncStream<SensorStatus>.Continuation
    ) {
        queue.async { [self] in
            self.frames = frames
            self.statuses = statuses
            meter.reset()
            frameCount = 0
            framesWithoutDepth = 0
            firstTimestamp = nil
            lastTimestamp = nil
            lastRateLog = nil
            hasReportedRunning = false
            lastTracking = ""
        }
    }

    /// Called after the session is paused. Logs a summary and ends the streams.
    func end() {
        queue.async { [self] in
            var details = ["frames": String(frameCount), "framesWithoutDepth": String(framesWithoutDepth)]
            if let first = firstTimestamp, let last = lastTimestamp, last > first {
                details["seconds"] = String(format: "%.1f", last - first)
                details["averageFps"] = String(format: "%.1f", Double(frameCount - 1) / (last - first))
            }
            log.info("sensor", "Sensor session stopped", details)
            statuses?.yield(.stopped)
            statuses?.finish()
            frames?.finish()
            statuses = nil
            frames = nil
        }
    }

    /// Handles one frame's worth of values, already copied out of the ARKit frame.
    private func receive(timestamp: TimeInterval, depth: DepthFrame?) {
        guard let frames else { return }
        if !hasReportedRunning {
            hasReportedRunning = true
            statuses?.yield(.running)
            log.info("sensor", "First frame received", ["hasDepth": depth == nil ? "no" : "yes"])
        }
        frameCount += 1
        if depth == nil {
            framesWithoutDepth += 1
        }
        if firstTimestamp == nil {
            firstTimestamp = timestamp
        }
        lastTimestamp = timestamp
        meter.record(timestamp)
        logRateIfDue(at: timestamp)
        frames.yield(SensorFrame(timestamp: timestamp, depth: depth))
    }

    private func logRateIfDue(at timestamp: TimeInterval) {
        guard let last = lastRateLog else {
            lastRateLog = timestamp
            return
        }
        guard timestamp - last >= Self.rateLogInterval else { return }
        lastRateLog = timestamp
        log.info(
            "sensor", "Frame rate",
            ["fps": ReadoutText.frameRate(meter.framesPerSecond), "frames": String(frameCount)])
    }

    // MARK: - Copying ARKit's pixel buffers

    /// Copies ARKit's depth data into a Core `DepthFrame`.
    ///
    /// A pixel buffer is a block of memory owned by the camera system. It must be
    /// "locked" before reading so the system does not change it underneath us. Each
    /// row may have padding bytes at its end, so rows are copied one at a time using
    /// the buffer's own row length rather than assuming rows are packed together.
    static func depthFrame(from data: ARDepthData, timestamp: TimeInterval) -> DepthFrame? {
        guard let depths = copyPixels(of: data.depthMap, as: Float32.self, format: kCVPixelFormatType_DepthFloat32)
        else { return nil }
        var confidence: [UInt8] = []
        if let map = data.confidenceMap,
            let values = copyPixels(of: map, as: UInt8.self, format: kCVPixelFormatType_OneComponent8)
        {
            confidence = values.pixels
        }
        return DepthFrame(
            width: depths.width, height: depths.height, depths: depths.pixels, confidence: confidence,
            timestamp: timestamp)
    }

    /// A grid of pixels copied out of a pixel buffer.
    private struct PixelGrid<Pixel> {
        let width: Int
        let height: Int
        let pixels: [Pixel]
    }

    private static func copyPixels<Pixel>(
        of buffer: CVPixelBuffer, as type: Pixel.Type, format: OSType
    ) -> PixelGrid<Pixel>? {
        guard CVPixelBufferGetPixelFormatType(buffer) == format else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width > 0, height > 0 else { return nil }
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard bytesPerRow >= width * MemoryLayout<Pixel>.stride else { return nil }
        var pixels: [Pixel] = []
        pixels.reserveCapacity(width * height)
        for row in 0..<height {
            let rowStart = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: Pixel.self)
            pixels.append(contentsOf: UnsafeBufferPointer(start: rowStart, count: width))
        }
        return PixelGrid(width: width, height: height, pixels: pixels)
    }

    static func describe(_ state: ARCamera.TrackingState) -> String {
        switch state {
        case .normal:
            return "normal"
        case .notAvailable:
            return "not available"
        case .limited(let reason):
            switch reason {
            case .initializing: return "limited: starting up"
            case .excessiveMotion: return "limited: moving too fast"
            case .insufficientFeatures: return "limited: too little detail in view"
            case .relocalizing: return "limited: relocalising"
            @unknown default: return "limited: other reason"
            }
        @unknown default:
            return "unknown"
        }
    }
}

extension FrameReceiver: ARSessionDelegate {
    // These methods run on `queue` (the session's delegate queue). They are marked
    // `nonisolated` so Swift does not assume they run on the main thread.

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Copy what is needed now and let the frame go (see the type comment above).
        let timestamp = frame.timestamp
        let depth = frame.sceneDepth.flatMap { Self.depthFrame(from: $0, timestamp: timestamp) }
        receive(timestamp: timestamp, depth: depth)
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let description = Self.describe(camera.trackingState)
        guard description != lastTracking else { return }
        lastTracking = description
        log.info("sensor", "Tracking changed", ["state": description])
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        if let arError = error as? ARError, arError.code == .cameraUnauthorized {
            log.warning("sensor", "Camera permission denied", ["status": "refused when asked"])
            statuses?.yield(.permissionDenied)
        } else {
            log.error("sensor", "Sensor session failed", ["reason": error.localizedDescription])
            statuses?.yield(.failed(reason: error.localizedDescription))
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        log.warning("sensor", "Sensor session interrupted")
        statuses?.yield(.interrupted)
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        log.info("sensor", "Sensor session resumed")
        statuses?.yield(.running)
    }
}
