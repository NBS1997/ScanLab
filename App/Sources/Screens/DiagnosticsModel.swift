import Foundation
import Observation
import ScanLabCore

/// What the Diagnostics screen shows, kept separate from the view so the view stays
/// simple. `@Observable` makes SwiftUI redraw when these values change.
@MainActor
@Observable
final class DiagnosticsModel {
    /// Shown in the list; reading more is slow and not useful on a phone screen.
    static let displayLimit = 500

    private let environment: AppEnvironment
    private(set) var events: [LogEvent] = []
    private(set) var totalEvents = 0
    private(set) var unreadableLines = 0
    private(set) var isLoading = false
    /// A file ready to hand to the share sheet after Export log.
    private(set) var exportURL: URL?
    /// Shown in place when an export fails (mockups decision Q3-A).
    private(set) var exportError: String?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var buildInfo: BuildInfo { environment.buildInfo }

    func expiryText(now: Date = Date()) -> String {
        buildInfo.expiryDescription(now: now)
    }

    func buildDateText() -> String {
        buildInfo.buildDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown"
    }

    func reload() async {
        isLoading = true
        let result = await environment.log.readAll()
        events = result.newestFirst(limit: Self.displayLimit)
        totalEvents = result.events.count
        unreadableLines = result.unreadableLines
        isLoading = false
    }

    /// Writes the log as text to a temporary file for the share sheet (FR-10.3).
    /// The file is prepared when the screen opens, so the share button works at once;
    /// that preparation is not itself logged, or every visit would add an entry.
    func prepareExport() async {
        exportError = nil
        let text = await environment.log.exportText()
        let url = URL.temporaryDirectory.appending(path: "ScanLab-log-\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            exportURL = url
        } catch {
            // Errors are shown where they happen and logged (mockups Q3-A, FR-10.1).
            exportURL = nil
            exportError = "Could not prepare the log file: \(error.localizedDescription)"
            environment.log.error("log", "Log export failed", ["reason": error.localizedDescription])
        }
    }

    /// The Export screen for the built-in sample model, so export can be tried before
    /// scanning exists (unit U04). The model is built when the screen opens, off the
    /// main thread.
    func makeSampleExportModel() -> ExportModel {
        ExportModel(
            name: SampleMeshes.stepBlockName, service: ExportService(log: environment.log),
            loadMesh: { SampleMeshes.stepBlock() })
    }

    /// Shown under "Add sample to library" until the next attempt.
    private(set) var sampleMessage: String?
    private(set) var sampleFailed = false
    private(set) var isAddingSample = false

    /// Saves the built-in sample as a scan (method "sample"), so the library, Scan
    /// detail, rename and delete can be tried before capture exists (Bolt 5). The
    /// library logs the result; the model is built off the main thread.
    func addSampleToLibrary() async {
        guard !isAddingSample else { return }
        isAddingSample = true
        defer { isAddingSample = false }
        sampleMessage = nil
        let mesh = await Task.detached(priority: .userInitiated) { SampleMeshes.stepBlock() }.value
        do {
            let scan = try await environment.library.add(mesh: mesh, method: .sample)
            sampleFailed = false
            sampleMessage = "Added \u{201C}\(scan.name)\u{201D} to the library."
        } catch {
            sampleFailed = true
            sampleMessage = error.localizedDescription
        }
        await reload()
    }

    /// Called when the owner taps Export log.
    func recordExportTapped() {
        environment.log.info("log", "Log export opened", ["events": String(totalEvents)])
    }
}
