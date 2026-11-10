import Foundation
import ScanLabCore

/// Runs accuracy checks (AccuracyService in services.md): loads the scan and the
/// reference, runs Core's stage 1 pipeline in the background with progress and
/// cancel, stores the report next to the scan, and logs every run so a result can be
/// understood from Diagnostics alone.
struct AccuracyService: Sendable {
    let library: ScanLibrary
    let reference: BundledReference
    let calipers: CaliperStore
    let log: any Logging

    /// The report saved with the scan, or `nil` when there is none or it cannot be
    /// read (which is logged, and the check can simply be run again).
    func savedReport(for scanID: UUID) async -> AccuracyReport? {
        do {
            guard let data = try await library.reportData(for: scanID) else { return nil }
            return try AccuracyReportCodec.decode(data)
        } catch {
            let reason = error.localizedDescription
            log.warning("accuracy", "Saved report not read", ["scan": short(scanID), "reason": reason])
            return nil
        }
    }

    /// Checks the scan against the reference object and saves the report.
    ///
    /// The heavy work runs on a background task. If the caller is cancelled (the owner
    /// taps Cancel or leaves the screen), that task is told to stop too; it checks
    /// between rounds and stops within a fraction of a second. Nothing is saved then,
    /// and an earlier report stays as it was.
    func run(scanID: UUID, progress: @escaping @Sendable (AccuracyProgress) -> Void) async throws -> AccuracyReport {
        let started = Date()
        log.info("accuracy", "Accuracy check started", ["scan": short(scanID)])
        do {
            let surface = try await reference.surface()
            let mesh = try await library.mesh(for: scanID)
            let request = AccuracyRequest(scanID: scanID, surface: surface, caliperValuesEntered: caliperCount())
            let worker = Task.detached(priority: .userInitiated) {
                try AccuracyPipeline.run(scan: mesh, request: request, progress: progress)
            }
            let report = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
            }
            try await library.attachReport(try AccuracyReportCodec.encode(report), to: scanID)
            log.info("accuracy", "Accuracy check finished", details(report, scanID: scanID, started: started))
            return report
        } catch is CancellationError {
            let elapsed = milliseconds(since: started)
            log.info("accuracy", "Accuracy check cancelled", ["scan": short(scanID), "ms": elapsed])
            throw CancellationError()
        } catch {
            log.error(
                "accuracy", "Accuracy check failed",
                ["scan": short(scanID), "reason": error.localizedDescription, "ms": milliseconds(since: started)])
            throw error
        }
    }

    /// How many caliper values are entered; a damaged file counts as none (logged).
    private func caliperCount() -> Int {
        do {
            return try calipers.load().enteredCount
        } catch {
            log.warning("accuracy", "Caliper values not read", ["reason": error.localizedDescription])
            return 0
        }
    }

    /// Everything about a run worth keeping in the diagnostics log: the match figures,
    /// the verdict, each size class's 95% figure and how long each step took.
    private func details(_ report: AccuracyReport, scanID: UUID, started: Date) -> [String: String] {
        let match = report.match
        var details = [
            "scan": short(scanID), "quality": match.quality.rawValue, "verdict": report.verdictLevel.rawValue,
            "rmsMm": AccuracyText.millimetres(match.rmsMillimetres, decimals: 3),
            "coverage": AccuracyText.percent(match.coverage), "inliers": AccuracyText.percent(match.inlierFraction),
            "iterations": String(match.iterations), "starts": String(match.startsTried),
            "points": String(report.pointsUsed), "background": String(report.backgroundRemoved),
            "calipers": String(report.caliperValuesEntered), "ms": milliseconds(since: started),
        ]
        for row in report.sizeClasses {
            details["p95Mm." + row.id] = AccuracyText.millimetres(row.within95Millimetres, decimals: 3)
        }
        for (step, time) in report.stepMilliseconds {
            details["ms." + step] = String(time)
        }
        if !report.reasons.isEmpty {
            details["reasons"] = report.reasons.joined(separator: " ")
        }
        return details
    }

    private func short(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private func milliseconds(since start: Date) -> String {
        String(Int(Date().timeIntervalSince(start) * 1000))
    }
}
