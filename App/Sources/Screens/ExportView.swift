import ScanLabCore
import SwiftUI
import UIKit

/// Mockups screen 5, shown as a sheet: choose the detail level and file type, then
/// choose where to save (US-11). The raw-capture switch arrives with photo capture
/// (unit U08), when there is a raw capture to export.
struct ExportView: View {
    @State var model: ExportModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    LabeledContent("Name", value: model.name)
                    LabeledContent("Size", value: model.dimensionsText)
                    LabeledContent("Faces", value: model.sourceFacesText)
                }

                Section {
                    Picker("Detail level", selection: $model.selectedDetail) {
                        ForEach(ExportDetail.allCases) { detail in
                            DetailRow(detail: detail, faces: model.faceText(for: detail))
                                .tag(detail)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Detail level")
                }

                Section {
                    Picker("File type", selection: $model.selectedFormat) {
                        ForEach(MeshFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("File type")
                } footer: {
                    Text("Files are written in millimetres.")
                }

                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .accessibilityLabel("Export failed. \(error)")
                    }
                }

                if let saved = model.savedMessage {
                    Section {
                        Label(saved, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    saveButton
                } footer: {
                    Text("The phone's file chooser opens, so you can save to iCloud Drive or another folder.")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $model.pendingExport) { pending in
                DocumentExportPicker(url: pending.url) { outcome in
                    model.pickerFinished(outcome)
                }
                .ignoresSafeArea()
                .onDisappear { model.pickerDismissed() }
            }
            .task { await model.prepareLevels() }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await model.chooseWhereToSave() }
        } label: {
            if model.isWriting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Writing file…")
                }
            } else {
                Label("Choose where to save…", systemImage: "square.and.arrow.down")
            }
        }
        .disabled(!model.canSave)
        .accessibilityHint("Writes the file, then opens the file chooser.")
    }
}

/// One detail level: its name, what it is for, and its face count.
private struct DetailRow: View {
    let detail: ExportDetail
    let faces: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(detail.displayName)
            Text(faces)
                .font(.subheadline)
                .monospacedDigit()
            Text(detail.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The phone's own "save to Files" chooser, given a finished file to copy. The
/// copy lands under the file's own name, wherever the owner chooses, including
/// iCloud Drive (FR-7.4).
struct DocumentExportPicker: UIViewControllerRepresentable {
    let url: URL
    let onFinish: @MainActor (PickerOutcome) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onFinish: @MainActor (PickerOutcome) -> Void

        init(onFinish: @escaping @MainActor (PickerOutcome) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish(urls.first.map(PickerOutcome.saved) ?? .cancelled)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish(.cancelled)
        }
    }
}

#Preview {
    ExportView(
        model: ExportModel(
            name: SampleMeshes.stepBlockName, service: ExportService(log: MemoryLog()),
            loadMesh: { SampleMeshes.stepBlock(subdivisions: 1) }))
}
