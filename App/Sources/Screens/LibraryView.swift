import ScanLabCore
import SwiftUI
import UIKit

/// The opening screen (mockups screen 1, US-10): every saved scan with its thumbnail,
/// name, method, date, size and an accuracy mark. Tap opens Scan detail; swipe left
/// to delete; touch and hold to rename. Pull down to refresh.
struct LibraryView: View {
    let environment: AppEnvironment
    @State private var model: LibraryModel
    @State private var renaming: Scan?
    @State private var draftName = ""
    @State private var deleting: LibraryRow?

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: LibraryModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scans")
                .navigationDestination(for: UUID.self) { id in
                    ScanDetailView(model: ScanDetailModel(environment: environment, scanID: id))
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink("Diagnostics") {
                            DiagnosticsView(model: DiagnosticsModel(environment: environment))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            ExploreView(model: ExploreModel(environment: environment))
                        } label: {
                            Label("Explore", systemImage: "camera.viewfinder")
                                .labelStyle(.titleAndIcon)
                        }
                        .accessibilityHint("Shows the live camera and depth sensor")
                    }
                }
                .alert("Rename scan", isPresented: isRenaming) {
                    TextField("Name", text: $draftName)
                    Button("Save") { saveRename() }
                    Button("Cancel", role: .cancel) { renaming = nil }
                } message: {
                    Text("Up to \(ScanNaming.maximumLength) characters.")
                }
                .confirmationDialog(
                    deleting.map { ScanText.deleteTitle($0.scan) } ?? "Delete scan?",
                    isPresented: isDeleting, titleVisibility: .visible, presenting: deleting
                ) { row in
                    Button("Delete scan", role: .destructive) {
                        Task { await model.delete(row.id) }
                    }
                } message: { row in
                    Text(ScanText.deleteMessage(row.scan, storage: row.storage))
                }
                // Runs on first showing and again on coming back from Scan detail,
                // Explore or Diagnostics, where a scan may have been renamed, deleted
                // or added.
                .onAppear {
                    Task { await model.reload() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = model.loadError, model.rows.isEmpty {
            ContentUnavailableView {
                Label("Scans could not be read", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try again") { Task { await model.reload() } }
            }
        } else if model.rows.isEmpty && model.hasLoaded {
            ContentUnavailableView {
                Label("No scans yet", systemImage: "cube.transparent")
            } description: {
                Text(
                    "Scanning arrives in a later build. To try the library now, open Diagnostics "
                        + "and add the sample model. Explore shows the live depth sensor.")
            }
            .refreshable { await model.reload() }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if let error = model.actionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            ForEach(model.rows) { row in
                NavigationLink(value: row.id) {
                    ScanRow(row: row)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleting = row
                    }
                }
                .contextMenu {
                    Button("Rename", systemImage: "pencil") { startRename(row.scan) }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = row }
                }
                .accessibilityAction(named: "Rename") { startRename(row.scan) }
                .accessibilityAction(named: "Delete") { deleting = row }
            }
            if model.unreadable > 0 {
                Label(
                    "\(model.unreadable) scan(s) could not be read and are not shown. They have not been removed.",
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
        .refreshable { await model.reload() }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func startRename(_ scan: Scan) {
        draftName = scan.name
        renaming = scan
    }

    private func saveRename() {
        guard let scan = renaming else { return }
        renaming = nil
        let name = draftName
        Task { await model.rename(scan.id, to: name) }
    }
}

/// One scan in the list: thumbnail, name, "method · date · size", and a tick when an
/// accuracy report exists.
private struct ScanRow: View {
    let row: LibraryRow

    var body: some View {
        HStack(spacing: 12) {
            ScanThumbnail(image: row.thumbnail)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.scan.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(ScanText.summary(row.scan, storage: row.storage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if row.scan.hasAccuracyReport {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Has an accuracy report")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A scan's picture, or a plain icon when it has none.
struct ScanThumbnail: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "cube")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

#Preview {
    LibraryView(environment: .preview())
}
