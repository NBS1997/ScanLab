import ScanLabCore
import SwiftUI

/// The Accuracy screen, stage 1 (mockups screen 8; US-13, FR-9.2–9.4, FR-9.6): match
/// quality first, then the one-sentence verdict, then surface error by size class.
/// When the match is unreliable it says so and shows no figures. The per-feature table
/// and Compare methods arrive with stage 2 (unit U11).
struct AccuracyView: View {
    @State var model: AccuracyModel
    @State private var referenceSheet: ReferenceSheet?

    var body: some View {
        List {
            Section {
                LabeledContent(model.scanName, value: model.methodText)
                    .accessibilityAddTraits(.isHeader)
            }
            phaseContent
            caliperSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Accuracy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) { bottomBar }
        }
        .sheet(item: $referenceSheet, onDismiss: { model.refreshCaliperCount() }) { sheet in
            ReferenceObjectView(model: sheet.model)
        }
        .task { await model.appear() }
        .onDisappear { model.cancel() }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .loading:
            Section { ProgressView("Opening the report…") }
        case .running(let progress):
            Section {
                ProgressView(value: progress.fraction) {
                    Text("\(progress.step.displayName)…")
                } currentValueLabel: {
                    Text(AccuracyText.percent(progress.fraction))
                }
                Text("Comparing the scan with the reference object's true shape. This takes a few seconds.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .finished(let report):
            ReportSections(report: report)
        case .cancelled:
            Section {
                Label("Check cancelled. Nothing was saved.", systemImage: "xmark.circle")
            }
        case .failed(let reason):
            Section {
                Label("The check could not be done.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text(reason)
                    .font(.footnote)
            }
        }
    }

    /// The prompt to enter caliper values (interaction-spec.md, Accuracy "Empty"
    /// state). Stage 1 does not need them; stage 2 compares features with them.
    private var caliperSection: some View {
        Section {
            if let count = model.caliperCount {
                if count == 0 {
                    Text(
                        "No caliper values yet. Enter them from the measurement sheet so later reports can "
                            + "compare each feature with your measurements.")
                } else {
                    LabeledContent("Caliper values", value: "\(count) entered")
                }
            }
            Button("Reference object…", systemImage: "ruler") {
                referenceSheet = ReferenceSheet(model: model.makeReferenceModel())
            }
            .accessibilityHint("Enter or edit your caliper measurements")
        } header: {
            Text("Your measurements")
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if model.isRunning {
            Button("Cancel", systemImage: "xmark") { model.cancel() }
                .accessibilityHint("Stops the check; an earlier report is kept")
        } else {
            Button("Check again", systemImage: "arrow.clockwise") { model.start() }
                .disabled(model.phase.isLoading)
                .accessibilityHint("Compares the scan with the reference object again")
        }
        Spacer()
    }
}

extension AccuracyModel.Phase {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// The Reference object sheet's contents, with an identity so SwiftUI can present it.
private struct ReferenceSheet: Identifiable {
    let id = UUID()
    let model: ReferenceObjectModel
}

/// A finished report: match, verdict, then the size-class table or, when unreliable,
/// the reasons instead of any figures (FR-9.4).
private struct ReportSections: View {
    let report: AccuracyReport

    var body: some View {
        Section {
            HStack {
                Image(systemName: qualitySymbol)
                    .foregroundStyle(qualityColour)
                    .accessibilityHidden(true)
                Text(report.matchLine)
                    .font(.headline.monospacedDigit())
            }
            LabeledContent("Reference surface found", value: AccuracyText.percent(report.match.coverage))
            LabeledContent("Scan close to the shape", value: AccuracyText.percent(report.match.inlierFraction))
            Text(report.verdict)
                .font(.body.weight(.semibold))
                .foregroundStyle(report.isReliable ? Color.primary : Color.red)
            ForEach(report.reasons, id: \.self) { reason in
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
            }
        } header: {
            Text("Match")
        }
        if report.isReliable {
            sizeClassSection
            countedSection
        }
        Section {
            LabeledContent("Checked", value: report.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Scan points", value: "\(report.pointsUsed)")
            LabeledContent("Background removed", value: "\(report.backgroundRemoved)")
            LabeledContent("Alignment rounds", value: "\(report.match.iterations)")
        } header: {
            Text("Details")
        }
    }

    private var sizeClassSection: some View {
        Section {
            ForEach(rows) { row in
                SizeClassRow(row: row)
            }
        } header: {
            Text("Surface error by size")
        } footer: {
            Text(
                "Distance from the scanned surface to the true shape, in millimetres. Mean shows bias "
                    + "(+ is outside), RMS the typical error, 95% the distance 95 in 100 points are within. "
                    + "These are surface distances, not feature sizes.")
        }
    }

    /// What the figures above are based on: the points counted and left out, and the
    /// reference surface the scan did not reach, in the verdict's own words.
    private var countedSection: some View {
        Section {
            if let measured = report.pointsMeasured, let excluded = report.pointsExcluded {
                LabeledContent("Points counted", value: measured.formatted())
                LabeledContent("Points left out", value: leftOutText(excluded))
            } else {
                Text("Points left out: unknown (an older report). Tap Check again to count them.")
                    .font(.footnote)
            }
            LabeledContent("Reference with no scan nearby", value: AccuracyText.percent(report.uncoveredShare))
            if let sentence = report.excludedSentence {
                Text(sentence)
                    .font(.footnote)
            }
            if let sentence = report.uncoveredSentence {
                Text(sentence)
                    .font(.footnote)
            }
        } header: {
            Text("What was counted")
        } footer: {
            Text(
                "Scan points too far from the reference shape are left out of every figure above, and parts of "
                    + "the reference the scan did not reach are not measured at all.")
        }
    }

    private func leftOutText(_ excluded: Int) -> String {
        guard let share = report.excludedShare else { return excluded.formatted() }
        return "\(excluded.formatted()) (\(AccuracyText.percent(share)))"
    }

    private var rows: [SizeClassResult] {
        (report.overall.map { [$0] } ?? []) + report.sizeClasses
    }

    private var qualitySymbol: String {
        switch report.match.quality {
        case .good: "checkmark.circle.fill"
        case .fair: "exclamationmark.circle.fill"
        case .unreliable: "xmark.octagon.fill"
        }
    }

    private var qualityColour: Color {
        switch report.match.quality {
        case .good: .green
        case .fair: .orange
        case .unreliable: .red
        }
    }
}

/// One line of the size-class table: the class, then mean, RMS and 95% figures. Read
/// by the screen reader as one sentence naming each column (accessibility check A10).
private struct SizeClassRow: View {
    let row: SizeClassResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.label)
                .font(.subheadline.weight(.semibold))
            HStack {
                figure("Mean", AccuracyText.signedMillimetres(row.meanMillimetres))
                figure("RMS", AccuracyText.millimetres(row.rmsMillimetres))
                figure("95%", "±" + AccuracyText.millimetres(row.within95Millimetres))
                figure("Points", "\(row.pointCount)")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
        .accessibilityValue(
            "mean \(AccuracyText.signedMillimetres(row.meanMillimetres)) millimetres, "
                + "RMS \(AccuracyText.millimetres(row.rmsMillimetres)) millimetres, "
                + "95 percent within \(AccuracyText.millimetres(row.within95Millimetres)) millimetres, "
                + "\(row.pointCount) points")
    }

    private func figure(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
