import Foundation
import Observation
import ScanLabCore

/// What the Export screen shows (mockups screen 5), kept apart from the view.
@MainActor
@Observable
final class ExportModel {
    let name: String
    var selectedDetail: ExportDetail = .fusionFriendly
    var selectedFormat: MeshFormat = .stl
    /// Set when a file is ready; showing the save chooser is driven by this.
    var pendingExport: PendingExport?
    private(set) var levels: [ExportDetail: LevelState] = [:]
    private(set) var dimensionsText = "Working out…"
    private(set) var sourceFacesText = "Working out…"
    private(set) var isWriting = false
    /// Shown in place on the screen until the next attempt (mockups decision Q3-A).
    private(set) var errorMessage: String?
    private(set) var savedMessage: String?

    private let service: ExportService
    private let loadMesh: @Sendable () -> Mesh
    private var started = false
    /// The written file until the chooser finishes. Kept apart from `pendingExport`
    /// because SwiftUI clears that binding itself when the sheet is swiped away.
    private var activeExport: PendingExport?

    init(name: String, service: ExportService, loadMesh: @escaping @Sendable () -> Mesh) {
        self.name = name
        self.service = service
        self.loadMesh = loadMesh
    }

    /// Whether the chosen level is ready and nothing is being written.
    var canSave: Bool {
        guard !isWriting, case .ready = levels[selectedDetail] else { return false }
        return true
    }

    /// The face count shown beside each level before export (FR-7.3).
    func faceText(for detail: ExportDetail) -> String {
        switch levels[detail] {
        case .ready(let mesh): Units.faceCount(mesh.faceCount)
        case .failed(let reason): "Not available: \(reason)"
        case .working, nil: "Working out…"
        }
    }

    /// Runs once when the screen opens.
    func prepareLevels() async {
        guard !started else { return }
        started = true
        service.log.info("export", "Export opened", ["model": name])
        for detail in ExportDetail.allCases {
            levels[detail] = .working
        }
        let prepared = await service.prepareLevels(name: name, loadMesh: loadMesh)
        levels = prepared.levels
        sourceFacesText = Units.faceCount(prepared.source.faceCount)
        dimensionsText = prepared.source.boundingBox.map { Units.formatDimensions($0.size) } ?? "Empty model"
    }

    /// Writes the file, then opens the save chooser.
    func chooseWhereToSave() async {
        guard case .ready(let mesh) = levels[selectedDetail], !isWriting else { return }
        errorMessage = nil
        savedMessage = nil
        isWriting = true
        defer { isWriting = false }
        do {
            let pending = try await service.writeTemporaryFile(
                mesh, name: name, detail: selectedDetail, format: selectedFormat)
            activeExport = pending
            pendingExport = pending
        } catch {
            // Already logged by the service; shown here with its reason and next step.
            errorMessage = error.localizedDescription
        }
    }

    /// Called by the save chooser when the owner saves or cancels.
    func pickerFinished(_ outcome: PickerOutcome) {
        guard let pending = activeExport else { return }
        activeExport = nil
        pendingExport = nil
        service.finish(pending, outcome: outcome)
        if case .saved(let destination) = outcome {
            savedMessage = "Saved \(destination.lastPathComponent)."
        }
    }

    /// Called when the chooser's sheet closes by any route, such as a swipe down,
    /// which does not always report a cancel.
    func pickerDismissed() {
        pickerFinished(.cancelled)
    }
}
