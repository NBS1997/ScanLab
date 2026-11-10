import ScanLabCore
import SwiftUI

/// The Reference object sheet (US-12, FR-8.6): the features from the measurement
/// sheet, grouped as on paper, each with its design value and a box for the caliper
/// value in millimetres (or degrees for angles). Values are checked as they are typed;
/// Save is available once nothing typed is unusable.
struct ReferenceObjectView: View {
    @State var model: ReferenceObjectModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Reference object")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if model.save() { dismiss() }
                        }
                        .disabled(!model.canSave)
                        .accessibilityHint(model.canSave ? "Saves your values" : "Fix the values marked in red")
                    }
                }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Reading the feature table…")
        case .failed(let reason):
            ContentUnavailableView {
                Label("Reference object could not be read", systemImage: "exclamationmark.triangle")
            } description: {
                Text(reason)
            }
        case .ready:
            list
        }
    }

    private var list: some View {
        List {
            Section {
                Text(
                    "Type your caliper values from the measurement sheet. Leave a box blank if you did not "
                        + "measure that feature: it is simply left out."
                )
                .font(.callout)
                if let error = model.saveError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                LabeledContent("Entered", value: "\(model.enteredCount) of \(model.rows.count)")
            }
            ForEach(model.kinds, id: \.self) { kind in
                Section(kind.groupTitle) {
                    ForEach(model.rows(of: kind)) { row in
                        CaliperRow(row: row) { model.update(row.id, text: $0) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// One feature: its ID and description, the design value, the caliper box with its
/// unit, any message about the value, and the measuring instruction on request.
private struct CaliperRow: View {
    let row: ReferenceObjectModel.Row
    let onChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.feature.id)
                    .font(.headline.monospaced())
                Text(row.feature.summary)
                    .font(.subheadline)
            }
            HStack {
                Text("Design \(CaliperValidation.format(row.feature.designValue)) \(row.feature.unit.symbol)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("—", text: Binding(get: { row.text }, set: onChange))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: 110)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(row.feature.id) caliper value in \(row.feature.unit.spokenName)")
                Text(row.feature.unit.symbol)
                    .accessibilityHidden(true)
            }
            message
            DisclosureGroup("How to measure") {
                Text(row.feature.howToMeasure)
                    .font(.footnote)
            }
            .font(.footnote)
        }
        .padding(.vertical, 2)
    }

    /// Problems in red and warnings in orange, always in words as well as colour
    /// (accessibility check A6).
    @ViewBuilder
    private var message: some View {
        switch row.check {
        case .invalid(let reason):
            Label(reason, systemImage: "xmark.octagon")
                .font(.footnote)
                .foregroundStyle(.red)
        case .valid(_, .some(let warning)):
            Label(warning, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }
}

#Preview {
    ReferenceObjectView(model: ReferenceObjectModel(environment: .preview()))
}
