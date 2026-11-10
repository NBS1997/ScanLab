import ScanLabCore
import SwiftUI

/// Mockups screen 4 (US-10, FR-6.4): the model, which can be turned and zoomed, the
/// Shape and Edges chips, the scan's details, and a bottom bar with Check accuracy and
/// Export. Rename and Delete are in the "•••" menu at the top. Sideways, the model
/// sits beside the details.
struct ScanDetailView: View {
    @State var model: ScanDetailModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var exportSheet: ExportSheet?
    @State private var showingRename = false
    @State private var draftName = ""
    @State private var showingDelete = false
    @State private var resetCount = 0

    var body: some View {
        layout
            .navigationTitle(model.scan?.name ?? "Scan")
            // An inline title stays on one line and is cut short with "…" if long.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { moreMenu }
                ToolbarItemGroup(placement: .bottomBar) { bottomBar }
            }
            .sheet(item: $exportSheet) { sheet in
                ExportView(model: sheet.model)
            }
            .alert("Rename scan", isPresented: $showingRename) {
                TextField("Name", text: $draftName)
                Button("Save") {
                    let name = draftName
                    Task { await model.rename(to: name) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Up to \(ScanNaming.maximumLength) characters.")
            }
            .confirmationDialog(
                model.scan.map(ScanText.deleteTitle) ?? "Delete scan?", isPresented: $showingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete scan", role: .destructive) {
                    Task { await model.delete() }
                }
            } message: {
                if let scan = model.scan {
                    Text(ScanText.deleteMessage(scan, storage: model.storage))
                }
            }
            .onChange(of: model.isDeleted) { _, deleted in
                if deleted { dismiss() }
            }
            .task { await model.load() }
    }

    @ViewBuilder
    private var layout: some View {
        if verticalSizeClass == .compact {
            HStack(spacing: 0) {
                modelArea
                details
                    .frame(maxWidth: 380)
            }
        } else {
            VStack(spacing: 0) {
                modelArea
                details
            }
        }
    }

    /// The model, its chips and a reset button.
    private var modelArea: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                modelContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if case .shown = model.modelState, model.showShape {
                    Button("Reset view", systemImage: "arrow.counterclockwise") {
                        resetCount += 1
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .padding(8)
                    .accessibilityHint("Turns the model back to the starting view")
                }
            }
            LayerChips(showShape: $model.showShape)
        }
        .padding(.bottom, 8)
        .frame(minHeight: 240)
    }

    @ViewBuilder
    private var modelContent: some View {
        switch model.modelState {
        case .loading:
            ProgressView("Opening model…")
        case .failed(let reason):
            ContentUnavailableView {
                Label("Model could not be shown", systemImage: "exclamationmark.triangle")
            } description: {
                Text(reason)
            }
        case .shown(let geometry):
            if model.showShape {
                ModelView(geometry: geometry, resetCount: resetCount)
                    .accessibilityElement()
                    .accessibilityLabel("3D model")
                    .accessibilityValue(modelDescription)
                    .accessibilityHint("Drag to turn, pinch to zoom.")
            } else {
                Text("Shape layer is off.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Read out for the model view (accessibility check A9).
    private var modelDescription: String {
        guard let scan = model.scan else { return "" }
        return "\(ScanText.size(scan)), \(Units.faceCount(scan.faceCount))"
    }

    private var details: some View {
        List {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            if let scan = model.scan {
                Section {
                    LabeledContent("Method", value: ScanText.method(scan))
                    LabeledContent("Size", value: ScanText.size(scan))
                    LabeledContent("Faces", value: Units.faceCount(scan.faceCount))
                    LabeledContent("Raw capture", value: ScanText.rawCapture(scan, storage: model.storage))
                    LabeledContent("On this phone", value: model.storage.map { Units.storage($0.totalBytes) } ?? "—")
                    LabeledContent(
                        "Saved", value: scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                } footer: {
                    Text("Check accuracy: \(ScanDetailModel.accuracyUnavailableReason.lowercased()).")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var moreMenu: some View {
        Menu {
            Button("Rename", systemImage: "pencil") {
                draftName = model.scan?.name ?? ""
                showingRename = true
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                showingDelete = true
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .disabled(model.scan == nil)
        .accessibilityLabel("More actions")
        .accessibilityHint("Rename or delete this scan")
    }

    @ViewBuilder
    private var bottomBar: some View {
        Button("Check accuracy", systemImage: "ruler") {}
            .disabled(!model.canCheckAccuracy)
            .accessibilityHint(ScanDetailModel.accuracyUnavailableReason)
        Spacer()
        Button("Export", systemImage: "square.and.arrow.up") {
            exportSheet = model.makeExportModel().map(ExportSheet.init)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canExport)
        .accessibilityHint("Choose the detail level and file type, then where to save")
    }
}

/// The Export sheet's contents, with an identity so SwiftUI can present it.
private struct ExportSheet: Identifiable {
    let id = UUID()
    let model: ExportModel
}

/// The Shape and Edges layer chips. Edges is shown but disabled until edge detection
/// arrives (unit U12), as on Explore.
private struct LayerChips: View {
    @Binding var showShape: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Toggle(isOn: $showShape) {
                    Label("Shape", systemImage: "cube")
                }
                .accessibilityLabel("Shape layer")
                Toggle(isOn: .constant(false)) {
                    Label("Edges", systemImage: "square.dashed")
                }
                .disabled(true)
                .accessibilityLabel("Edges layer")
                .accessibilityHint(ScanDetailModel.edgesUnavailableReason)
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            Text("Edges: \(ScanDetailModel.edgesUnavailableReason.lowercased())")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    NavigationStack {
        ScanDetailView(model: ScanDetailModel(environment: .preview(), scanID: UUID()))
    }
}
