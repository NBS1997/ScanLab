import ScanLabCore
import SwiftUI

/// Mockups screen 9: which build this is, when it expires, and what the app has done.
struct DiagnosticsView: View {
    @State var model: DiagnosticsModel

    var body: some View {
        List {
            Section("Build") {
                LabeledContent("Version", value: model.buildInfo.versionDescription)
                LabeledContent("Built", value: model.buildDateText())
                LabeledContent("Build expires", value: model.expiryText())
            }

            Section {
                if let error = model.exportError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if model.unreadableLines > 0 {
                    Label(
                        "\(model.unreadableLines) unreadable log line(s) skipped",
                        systemImage: "exclamationmark.circle"
                    )
                    .foregroundStyle(.orange)
                }
                if model.events.isEmpty && !model.isLoading {
                    Text("No activity yet").foregroundStyle(.secondary)
                }
                ForEach(Array(model.events.enumerated()), id: \.offset) { _, event in
                    EventRow(event: event)
                }
            } header: {
                Text("Activity")
            } footer: {
                if model.totalEvents > model.events.count {
                    Text("Showing the latest \(model.events.count) of \(model.totalEvents). Export includes all.")
                }
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                exportButton
            }
        }
        .refreshable { await model.reload() }
        .task {
            await model.reload()
            await model.prepareExport()
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        if let url = model.exportURL {
            ShareLink(item: url) {
                Label("Export log", systemImage: "square.and.arrow.up")
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    model.recordExportTapped()
                })
        } else {
            Button("Export log", systemImage: "square.and.arrow.up") {
                Task { await model.prepareExport() }
            }
        }
    }
}

/// One activity line: time and level, then the message and any details.
private struct EventRow: View {
    let event: LogEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(event.timestamp, format: .dateTime.hour().minute().second())
                    .monospacedDigit()
                Text(event.level.rawValue.uppercased())
                    .foregroundStyle(color)
                Text(event.category).foregroundStyle(.secondary)
            }
            .font(.caption)
            Text(event.message)
            let details = LogFormatter.detailsText(event.details)
            if !details.isEmpty {
                Text(details).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch event.level {
        case .info: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView(model: DiagnosticsModel(environment: .preview()))
    }
}
