import Foundation
import Observation
import ScanLabCore

/// What the Capture screen shows (mockups screen 3), kept apart from the view. The
/// rules live in Core's `SweepCaptureService`; this model listens to the camera's
/// streams, passes them on, and mirrors the results for SwiftUI to draw.
@MainActor
@Observable
final class CaptureModel {
    let capture: any LiveSweepCapturing
    private(set) var phase: CapturePhase = .idle
    private(set) var progress = SweepProgress.zero
    private(set) var status: SensorStatus = .starting
    /// When capturing began, for the timer at the top of the screen.
    private(set) var capturingSince: Date?

    @ObservationIgnored private let service: SweepCaptureService
    @ObservationIgnored private let log: any Logging
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(environment: AppEnvironment) {
        capture = environment.sweepCapture
        log = environment.log
        service = SweepCaptureService(
            capture: environment.sweepCapture, library: environment.library, log: environment.log)
    }

    /// The tracking prompt, shown only while capturing.
    var prompt: String? {
        guard phase == .capturing else { return nil }
        if status == .interrupted {
            return status.message
        }
        return progress.tracking.prompt
    }

    var statsText: String { CaptureText.stats(progress) }

    /// Finish needs a running capture with some surface in it.
    var canFinish: Bool { phase == .capturing && progress.faceCount > 0 }

    // MARK: - Actions

    /// Starts the camera. Also used by Try again after a failure.
    func start() {
        guard let streams = service.start() else { return }
        phase = service.phase
        progress = .zero
        status = .starting
        capturingSince = nil
        log.info("ui", "Capture shown", ["method": CaptureMethod.sweep.rawValue])
        // Two loops, one per stream. Both run on the main actor, as this model does.
        tasks.append(
            Task { [weak self] in
                for await status in streams.statuses {
                    self?.statusChanged(status)
                }
            })
        tasks.append(
            Task { [weak self] in
                for await progress in streams.progress {
                    self?.service.progressChanged(progress)
                    self?.progress = progress
                }
            })
    }

    /// Builds and saves the scan. Afterwards `phase` is `.saved` or `.failed`.
    func finish() async {
        guard service.session.allows(.finish) else { return }
        phase = .finishing
        phase = await service.finish()
        stopListening()
    }

    /// Closes without saving.
    func cancel() {
        // After a failure the capture has already stopped; there is nothing to cancel.
        if service.session.allows(.cancel) {
            service.cancel()
        }
        phase = service.phase
        stopListening()
    }

    /// Called when the screen goes away for any reason. A capture still running is
    /// cancelled so the camera never stays on behind another screen.
    func screenGone() {
        switch phase {
        case .idle, .preparing, .capturing:
            cancel()
        case .finishing, .saved, .failed, .cancelled:
            stopListening()
        }
    }

    // MARK: - Helpers

    private func statusChanged(_ newStatus: SensorStatus) {
        status = newStatus
        service.statusChanged(newStatus)
        let before = phase
        phase = service.phase
        if before != .capturing && phase == .capturing {
            capturingSince = Date()
        }
        if phase.isOver {
            stopListening()
        }
    }

    private func stopListening() {
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
}
