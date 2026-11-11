import Foundation
import Testing

@testable import ScanLabCore

@Suite("Accuracy reports")
struct AccuracyReportTests {
    @Test("a scan of the reference object's mesh is reliable, with figures near zero")
    func reliableFromMesh() throws {
        let surface = try AccuracyFixtures.surface.get()
        let scan = AccuracyFixtures.object.transformed(by: AccuracyFixtures.misplacement)
        var steps: [AccuracyStep] = []
        let report = try AccuracyPipeline.run(scan: scan, request: AccuracyFixtures.request(surface)) {
            steps.append($0.step)
        }
        #expect(report.isReliable && report.reasons.isEmpty)
        #expect(report.match.quality == .good)
        #expect(try #require(report.overall).rmsMillimetres < 0.01)
        #expect(report.verdict.hasPrefix("The measured surface is within ±0.00 mm"))
        #expect(report.verdictLevel == .good && !report.verdict.contains("is not counted"))
        #expect(report.overall?.label == "Measured surface")
        let counted = try #require(report.pointsMeasured) + (try #require(report.pointsExcluded))
        #expect(counted == report.pointsUsed - report.backgroundRemoved)
        #expect(report.verdict.hasSuffix("These are surface distances, not feature sizes."))
        #expect(report.pointsUsed == 3000 && report.caliperValuesEntered == 3)
        #expect(report.transform.count == 12)
        #expect(Set(report.stepMilliseconds.keys) == ["sampling", "isolating", "aligning", "measuring"])
        #expect(steps.first == .sampling && steps.last == .measuring && steps.contains(.aligning))
        #expect(report.matchLine.hasPrefix("Match good · 0.0"))
    }

    @Test("a ball is a different object: unreliable, with no figures")
    func sphereIsUnreliable() throws {
        let surface = try AccuracyFixtures.surface.get()
        let ball = AccuracyFixtures.sphere(radius: 0.05, centre: Vec3(0.3, 0.1, 0.05))
        let report = try AccuracyPipeline.run(scan: ball, request: AccuracyFixtures.request(surface))
        #expect(!report.isReliable)
        #expect(report.verdictLevel == .unreliable && report.match.quality == .unreliable)
        #expect(report.verdict == AccuracyReporting.unreliableVerdict)
        #expect(report.overall == nil && report.sizeClasses.isEmpty)
        #expect(report.reasons.contains { $0.contains("surface was found in the scan") })
    }

    @Test("the built-in sample model is not the reference object either")
    func sampleIsUnreliable() throws {
        let surface = try AccuracyFixtures.surface.get()
        let request = AccuracyFixtures.request(surface)
        let report = try AccuracyPipeline.run(scan: SampleMeshes.stepBlock(), request: request)
        #expect(!report.isReliable && report.overall == nil)
    }

    @Test("an empty scan cannot be checked")
    func emptyScan() throws {
        let surface = try AccuracyFixtures.surface.get()
        #expect(throws: AlignmentError.tooFewPoints(found: 0, needed: 100)) {
            try AccuracyPipeline.run(scan: .empty, request: AccuracyFixtures.request(surface))
        }
    }

    @Test("a cancelled check stops with a cancellation")
    func cancellation() async throws {
        let surface = try AccuracyFixtures.surface.get()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try AccuracyPipeline.run(scan: AccuracyFixtures.object, request: AccuracyFixtures.request(surface))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("the reliability rule's thresholds, each on its own")
    func rule() {
        let rule = ReliabilityRule()
        #expect(rule.quality(rmsResidual: 0.0004, coverage: 0.85, inlierFraction: 0.9) == .good)
        #expect(rule.quality(rmsResidual: 0.0008, coverage: 0.85, inlierFraction: 0.9) == .fair)
        #expect(rule.quality(rmsResidual: 0.0004, coverage: 0.7, inlierFraction: 0.9) == .fair)
        #expect(rule.quality(rmsResidual: 0.0021, coverage: 0.85, inlierFraction: 0.9) == .unreliable)
        #expect(rule.quality(rmsResidual: 0.0004, coverage: 0.59, inlierFraction: 0.9) == .unreliable)
        #expect(rule.quality(rmsResidual: 0.0004, coverage: 0.85, inlierFraction: 0.49) == .unreliable)
        let reasons = rule.problems(rmsResidual: 0.0034, coverage: 0.23, inlierFraction: 0.31)
        #expect(reasons.count == 3)
        #expect(reasons[0].hasPrefix("Only 23% of the reference object's surface"))
        #expect(reasons[1].contains("3.40 mm apart"))
        #expect(reasons[2].contains("31%"))
    }

    @Test("the verdict names the least accurate size class")
    func verdictWording() throws {
        let classes = try [
            row(.small, within95: 0.0009), row(.medium, within95: 0.0005), row(.large, within95: 0.0004),
        ]
        let overall = try row(nil, within95: 0.00062)
        let text = AccuracyReporting.verdict(overall: overall, classes: classes)
        let expected =
            "The measured surface is within ±0.62 mm of the true shape for 95% of the points counted; "
            + "least accurate on small features (±0.90 mm). These are surface distances, not feature sizes."
        #expect(text == expected)
        let large = try row(.large, within95: 0.001)
        let single = AccuracyReporting.verdict(overall: large, classes: [large])
        #expect(!single.contains("least accurate"))
    }

    @Test("a wide spread gives a limited verdict")
    func limitedVerdict() throws {
        let stats = try #require(DeviationStats([0.002, -0.0025, 0.003]))
        let deviation = DeviationResult(overall: stats, bySizeClass: [.large: stats], otherSurface: nil, excluded: 0)
        let report = AccuracyReporting.makeReport(
            alignment: alignment(rms: 0.0015), deviation: deviation,
            context: ReportContext(scanID: UUID(), createdAt: Date(), table: AccuracyFixtures.table))
        #expect(report.isReliable && report.verdictLevel == .limited && report.match.quality == .fair)
        #expect(report.sizeClasses.map(\.label) == ["Large (over 30 mm)"])
    }

    @Test("a good match with nothing measured is still unreliable")
    func nothingMeasured() {
        let empty = DeviationResult(overall: nil, bySizeClass: [:], otherSurface: nil, excluded: 10)
        let report = AccuracyReporting.makeReport(
            alignment: alignment(rms: 0.0001), deviation: empty,
            context: ReportContext(scanID: UUID(), createdAt: Date(), table: AccuracyFixtures.table))
        #expect(!report.isReliable && report.reasons.count == 1)
    }

    @Test("reports survive saving, and an unreliable report never reads back figures")
    func codec() throws {
        let stats = try #require(DeviationStats([0.0001, -0.0002]))
        let figures = SizeClassResult(sizeClass: .small, label: "Small", stats: stats)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let match = MatchSummary(rmsMillimetres: 0.2, coverage: 0.8, inlierFraction: 1)
        let report = AccuracyReport(
            scanID: UUID(), createdAt: date, match: match, verdictLevel: .good, verdict: "Fine.", overall: figures,
            sizeClasses: [figures])
        #expect(try AccuracyReportCodec.decode(AccuracyReportCodec.encode(report)) == report)
        var tampered = report
        tampered.isReliable = false
        let read = try AccuracyReportCodec.decode(AccuracyReportCodec.encode(tampered))
        #expect(read.overall == nil && read.sizeClasses.isEmpty)
        let minimal =
            #"{"scanID":"\#(report.scanID.uuidString)","createdAt":"2027-01-15T08:00:00Z","#
            + #""match":{"rmsMillimetres":1,"coverage":0.5,"inlierFraction":0.5,"iterations":3,"#
            + #""startsTried":36,"quality":"fair"},"future":true}"#
        let old = try AccuracyReportCodec.decode(Data(minimal.utf8))
        #expect(old.version == 1 && !old.isReliable && old.verdictLevel == .unreliable && old.transform.isEmpty)
        #expect(old.pointsMeasured == nil && old.pointsExcluded == nil && old.excludedShare == nil)
        #expect(report.version == 2)
        #expect(throws: StoreError.self) { try AccuracyReportCodec.decode(Data("{}".utf8)) }
    }

    @Test("figures are shown with a full stop and a true minus sign")
    func text() {
        #expect(AccuracyText.millimetres(1234.5678) == "1,234.57")
        #expect(AccuracyText.signedMillimetres(0.2) == "+0.20")
        #expect(AccuracyText.signedMillimetres(-0.2) == "\u{2212}0.20")
        #expect(AccuracyText.signedMillimetres(-0.001) == "0.00")
        #expect(AccuracyText.percent(0.846) == "85%")
        #expect(AccuracyStep.aligning.displayName == "Lining up with the reference")
    }

    /// A table row whose 95% figure is `within95` metres.
    private func row(_ sizeClass: SizeClass?, within95: Double) throws -> SizeClassResult {
        let stats = try #require(DeviationStats([within95]))
        return SizeClassResult(sizeClass: sizeClass, label: sizeClass?.displayName ?? "All", stats: stats)
    }

    private func alignment(rms: Double) -> AlignmentResult {
        AlignmentResult(
            transform: .identity, rmsResidual: rms, inlierFraction: 0.95, coverage: 0.7, iterations: 5,
            startsTried: 36)
    }
}
