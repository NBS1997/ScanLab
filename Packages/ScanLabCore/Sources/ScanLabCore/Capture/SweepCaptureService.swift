import Foundation

/// Runs one sweep capture from start to saved scan (CaptureService in services.md):
/// it keeps the `CaptureSession` rules, drives the `SweepCapturing` port, turns the
/// finished mesh z-up and saves it to the library. The Capture screen only shows what
/// this reports, so everything apart from the camera itself is tested here.
///
/// It lives on the main actor because the screen and the port do too; the heavy
/// work (merging the mesh, writing the files) happens inside the port and the
/// library, off the main thread.
///
/// Everything it does is written to the diagnostics log under `capture`.
@MainActor
public final class SweepCaptureService {
    public private(set) var session = CaptureSession()
    public var phase: CapturePhase { session.phase }

    private let capture: any SweepCapturing
    private let library: ScanLibrary
    private let log: any Logging
    private let clock: () -> Date
    private var startedAt: Date?
    private var lastProgress = SweepProgress.zero

    public init(
        capture: any SweepCapturing, library: ScanLibrary, log: any Logging,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.capture = capture
        self.library = library
        self.log = log
        self.clock = clock
    }

    /// Starts the camera. Returns the streams the screen listens to, or nil when a
    /// start is not allowed now (for example, a capture is already running).
    public func start() -> SweepStreams? {
        guard transition(.start) else { return nil }
        startedAt = clock()
        lastProgress = .zero
        log.info("capture", "Capture started", ["method": CaptureMethod.sweep.rawValue])
        return capture.start()
    }

    /// Passes on each status the camera reports: the first picture starts capturing;
    /// a refusal or failure ends the capture.
    public func statusChanged(_ status: SensorStatus) {
        switch status {
        case .running:
            if phase == .preparing {
                transition(.sensorReady)
            }
        case .permissionDenied:
            fail(.permissionDenied)
        case .unsupported(let reason):
            fail(.sensorUnavailable(reason))
        case .failed(let reason):
            fail(.sessionFailed(reason))
        case .starting, .interrupted, .stopped:
            break
        }
    }

    /// Remembers the latest progress, so the log can say how much had been captured.
    public func progressChanged(_ progress: SweepProgress) {
        lastProgress = progress
    }

    /// Builds, turns and saves the model. Returns the phase afterwards: `.saved` with
    /// the new scan's identity, or `.failed` with the reason. Nothing is saved on
    /// failure, and an empty capture saves nothing.
    @discardableResult
    public func finish() async -> CapturePhase {
        guard transition(.finish) else { return phase }
        log.info("capture", "Capture finishing", progressDetails)
        do {
            let captured = try await capture.finish()
            guard !captured.isEmpty else { throw CaptureError.nothingCaptured }
            // The platform's world has y up; every saved scan has z up (AxisConversion).
            let upright = captured.convertedFromYUp()
            let scan = try await library.add(mesh: upright, method: .sweep)
            transition(.saved(scan.id))
            var details = progressDetails
            details["faces"] = String(upright.faceCount)
            details["scan"] = String(scan.id.uuidString.prefix(8))
            log.info("capture", "Capture saved", details)
        } catch {
            fail(CaptureError(wrapping: error))
        }
        return phase
    }

    /// Closes the capture without saving. Not allowed while the scan is being saved.
    public func cancel() {
        guard transition(.cancel) else { return }
        capture.cancel()
        log.info("capture", "Capture cancelled", progressDetails)
    }

    // MARK: - Helpers

    private func fail(_ error: CaptureError) {
        let wasRunning = phase == .preparing || phase == .capturing
        guard transition(.fail(error)) else { return }
        if wasRunning {
            capture.cancel()
        }
        var details = progressDetails
        details["reason"] = error.errorDescription ?? String(describing: error)
        // A refused permission or an empty capture is the owner's to fix, not a fault.
        switch error {
        case .permissionDenied, .nothingCaptured, .noSpace:
            log.warning("capture", "Capture not saved", details)
        default:
            log.error("capture", "Capture not saved", details)
        }
    }

    /// Applies an event, logging (not crashing) when it is not allowed.
    @discardableResult
    private func transition(_ event: CaptureSessionEvent) -> Bool {
        do {
            try session.apply(event)
            return true
        } catch {
            log.warning("capture", "Capture step ignored", ["phase": phase.logName, "event": event.logName])
            return false
        }
    }

    private var progressDetails: [String: String] {
        var details = [
            "method": CaptureMethod.sweep.rawValue, "anchors": String(lastProgress.anchorCount),
            "faces": String(lastProgress.faceCount),
        ]
        if let startedAt {
            details["seconds"] = String(format: "%.1f", clock().timeIntervalSince(startedAt))
        }
        return details
    }
}
