import CoreGraphics
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
    /// Choosing the subject before scanning (SB-1 to SB-8).
    private(set) var choice = SubjectChoice()

    @ObservationIgnored private let service: SweepCaptureService
    @ObservationIgnored private let log: any Logging
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(environment: AppEnvironment) {
        capture = environment.sweepCapture
        log = environment.log
        service = SweepCaptureService(
            capture: environment.sweepCapture, library: environment.library, log: environment.log)
    }

    /// The prompt shown while capturing: an interruption, then the subject instruction
    /// until scanning begins, then tracking, memory and coverage (CD-4).
    var prompt: String? {
        guard phase == .capturing else { return nil }
        if status == .interrupted {
            return status.message
        }
        if let instruction = choice.instruction {
            return instruction
        }
        return progress.prompt
    }

    /// True while a tap on the camera picks the subject.
    var acceptsSubjectTaps: Bool {
        phase == .capturing && !choice.isScanning
    }

    var coverage: CoverageSummary? { progress.coverage }

    var statsText: String { CaptureText.stats(progress) }

    /// Finish needs scanning to have begun and some surface (SB-8).
    var canFinish: Bool { phase == .capturing && choice.isScanning && progress.faceCount > 0 }

    // MARK: - Actions

    /// Starts the camera. Also used by Try again after a failure.
    func start() {
        guard let streams = service.start() else { return }
        phase = service.phase
        progress = .zero
        status = .starting
        capturingSince = nil
        choice = SubjectChoice()
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

    // MARK: - Choosing the subject

    /// A tap on the camera view while choosing (SB-2).
    func tapped(at point: CGPoint, in size: CGSize) async {
        guard acceptsSubjectTaps, choice.tapped() else { return }
        capture.showSubject(nil, locked: false)
        let result = await capture.pickSubject(atViewPoint: point, viewSize: size)
        // The screen may have moved on (closed, or Scan everything) while Vision ran.
        guard choice.found(result) else { return }
        capture.showSubject(choice.box, locked: false)
    }

    /// Bigger (1.1) or Smaller (0.9) (SB-6).
    func resize(by factor: Double) {
        guard choice.resize(by: factor) else { return }
        capture.showSubject(choice.box, locked: false)
        log.info("ui", "Subject box resized", choice.box?.logDetails ?? [:])
    }

    /// Scan this: lock the box and start fusing inside it (SB-6, SB-7).
    func lockSubject() {
        guard choice.lock(), let box = choice.box else { return }
        capture.showSubject(box, locked: true)
        capture.beginScanning(in: box)
        log.info("ui", "Subject locked", box.logDetails)
    }

    /// Scan everything: no box, fuse the whole view (SB-1).
    func scanEverything() {
        guard choice.chooseWholeScene() else { return }
        capture.showSubject(nil, locked: false)
        capture.beginScanning(in: nil)
        log.info("ui", "Whole scene chosen")
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
