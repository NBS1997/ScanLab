import Foundation
import Observation
import ScanLabCore

/// What Scan detail shows (mockups screen 4), kept apart from the view.
@MainActor
@Observable
final class ScanDetailModel {
    /// The model view's states (interaction-spec.md, Model view component).
    enum ModelState {
        case loading
        case shown(ViewerGeometry)
        case failed(String)
    }

    /// Why Check accuracy cannot be used yet (unit U10 brings the accuracy report).
    static let accuracyUnavailableReason = "Comes with the accuracy report"
    static let edgesUnavailableReason = "Coming in a later build"

    let scanID: UUID
    private(set) var scan: Scan?
    private(set) var storage: StorageUse?
    private(set) var modelState: ModelState = .loading
    /// Shown in place when the scan could not be opened, renamed or deleted.
    private(set) var errorMessage: String?
    /// Set once the scan is deleted, so the screen closes.
    private(set) var isDeleted = false
    var showShape = true

    let environment: AppEnvironment
    /// The loaded model, kept for Export.
    private var mesh: Mesh?
    private var started = false

    init(environment: AppEnvironment, scanID: UUID) {
        self.environment = environment
        self.scanID = scanID
    }

    var library: ScanLibrary { environment.library }

    var canExport: Bool { mesh != nil }

    /// Check accuracy stays off in this build. Later it needs a reference scan
    /// (business rule SL-11).
    var canCheckAccuracy: Bool { false }

    /// Runs once when the screen opens: reads the details, then the model, then turns
    /// the model into the 3D view's buffers away from the main thread.
    func load() async {
        guard !started else { return }
        started = true
        let opened = Date()
        do {
            let scan = try await library.scan(scanID)
            self.scan = scan
            storage = try? await library.storage(for: scanID)
            let mesh = try await library.mesh(for: scanID)
            self.mesh = mesh
            let geometry = await Task.detached(priority: .userInitiated) { ViewerGeometry(mesh) }.value
            modelState = .shown(geometry)
            environment.log.info(
                "ui", "Scan detail shown",
                [
                    "scan": String(scanID.uuidString.prefix(8)), "faces": String(mesh.faceCount),
                    "ms": String(Int(Date().timeIntervalSince(opened) * 1000)),
                ])
        } catch {
            // The library has logged the failure; it is shown here with its reason.
            modelState = .failed(error.localizedDescription)
            if scan == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    @discardableResult
    func rename(to name: String) async -> Bool {
        errorMessage = nil
        do {
            scan = try await library.rename(scanID, to: name)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete() async {
        errorMessage = nil
        do {
            try await library.delete(scanID)
            isDeleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The Export sheet for this scan's model (the same sheet as the sample's).
    func makeExportModel() -> ExportModel? {
        guard let mesh, let scan else { return nil }
        environment.log.info("ui", "Export opened from scan", ["scan": String(scanID.uuidString.prefix(8))])
        return ExportModel(name: scan.name, service: ExportService(log: environment.log), loadMesh: { mesh })
    }
}
