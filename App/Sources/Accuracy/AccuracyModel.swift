import Foundation
import Observation
import ScanLabCore

/// What the Accuracy screen shows (mockups screen 8, stage 1), kept apart from the view.
@MainActor
@Observable
final class AccuracyModel {
    /// The screen's states (interaction-spec.md, Accuracy report row).
    enum Phase {
        case loading
        case running(AccuracyProgress)
        case finished(AccuracyReport)
        case cancelled
        case failed(String)
    }

    let scanID: UUID
    let scanName: String
    let methodText: String
    private(set) var phase: Phase = .loading
    /// How many caliper values are entered, once read.
    private(set) var caliperCount: Int?
    let environment: AppEnvironment
    private var runTask: Task<Void, Never>?
    private var started = false

    init(environment: AppEnvironment, scan: Scan) {
        self.environment = environment
        scanID = scan.id
        scanName = scan.name
        methodText = ScanText.method(scan)
    }

    var service: AccuracyService { environment.accuracy }

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    /// Runs once when the screen opens: shows the saved report, or checks the scan
    /// straight away when there is none, so one tap gives a report (FR-9.2).
    func appear() async {
        refreshCaliperCount()
        guard !started else { return }
        started = true
        environment.log.info("ui", "Accuracy shown", ["scan": String(scanID.uuidString.prefix(8))])
        if let saved = await service.savedReport(for: scanID) {
            phase = .finished(saved)
        } else {
            start()
        }
    }

    /// Checks the scan (again).
    func start() {
        runTask?.cancel()
        phase = .running(AccuracyProgress(step: .sampling, fraction: 0))
        let service = service
        let scanID = scanID
        // The task keeps the model alive only until the check ends.
        let model = self
        runTask = Task {
            do {
                let report = try await service.run(scanID: scanID) { update in
                    Task { @MainActor in model.show(update) }
                }
                model.phase = .finished(report)
            } catch is CancellationError {
                await model.restoreAfterCancel()
            } catch {
                model.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        runTask?.cancel()
    }

    /// Re-reads the caliper count, for example after the Reference object sheet closes.
    func refreshCaliperCount() {
        do {
            caliperCount = try environment.calipers.load().enteredCount
        } catch {
            caliperCount = 0
            environment.log.warning("accuracy", "Caliper values not read", ["reason": error.localizedDescription])
        }
    }

    func makeReferenceModel() -> ReferenceObjectModel {
        ReferenceObjectModel(environment: environment)
    }

    /// Progress arrives from the background; it is ignored once the run has ended, so
    /// a late update can never cover up the result.
    private func show(_ update: AccuracyProgress) {
        guard isRunning else { return }
        phase = .running(update)
    }

    /// After Cancel: the earlier report, if there is one, otherwise a "Cancelled" note.
    private func restoreAfterCancel() async {
        if let saved = await service.savedReport(for: scanID) {
            phase = .finished(saved)
        } else {
            phase = .cancelled
        }
    }
}

/// Scan detail pushes the Accuracy screen by handing SwiftUI the model, which needs
/// to be hashable; two models are the same only if they are the same object.
extension AccuracyModel: Hashable {
    nonisolated static func == (lhs: AccuracyModel, rhs: AccuracyModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
