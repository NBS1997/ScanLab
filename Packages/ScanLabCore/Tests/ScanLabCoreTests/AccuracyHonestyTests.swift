import Foundation
import Testing

@testable import ScanLabCore

/// Regression tests for the outside review of 2026-11-11: the report must say what it
/// counted. Points left out for being too far from the reference, and reference surface
/// the scan did not reach, used to vanish silently and flatter the figures.
@Suite("Accuracy report honesty")
struct AccuracyHonestyTests {
    @Test("a scan with a fifth of its points 8 mm out says so and is not rated good")
    func badlyBuiltPoints() throws {
        let surface = try AccuracyFixtures.surface.get()
        let clean = AccuracyFixtures.scan(of: AccuracyFixtures.object, count: 3000).points
        // Every fifth point is pushed 8 mm outwards: further than the 5 mm inlier distance.
        let damaged = clean.enumerated().map { index, point in
            guard index % 5 == 0 else { return point }
            return SurfacePoint(position: point.position + point.normal * 0.008, normal: point.normal)
        }
        let report = try AccuracyPipeline.run(points: damaged, request: AccuracyFixtures.request(surface))
        let share = try #require(report.excludedShare)
        #expect(share > 0.15 && share < 0.22)
        #expect(report.isReliable && report.verdictLevel == .limited)
        #expect(report.verdict.contains("of the scan was more than 5 mm from the reference shape and is not counted."))
        #expect(report.reasons.contains { $0.contains("allowed for a good rating") })
        #expect(report.excludedSentence.map { report.verdict.contains($0) } == true)
    }

    @Test("a clean scan mentions nothing left out and keeps its level")
    func cleanScan() throws {
        let surface = try AccuracyFixtures.surface.get()
        let clean = AccuracyFixtures.scan(of: AccuracyFixtures.object, count: 3000).points
        let report = try AccuracyPipeline.run(points: clean, request: AccuracyFixtures.request(surface))
        #expect(try #require(report.excludedShare) < AccuracyReporting.smallestShareMentioned)
        #expect(report.verdictLevel == .good && report.reasons.isEmpty)
        #expect(!report.verdict.contains("is not counted"))
        #expect(report.excludedSentence == nil)
        let inlierDistance = try #require(report.inlierDistanceMillimetres)
        let coverageRadius = try #require(report.coverageRadiusMillimetres)
        #expect(abs(inlierDistance - 5) < 1e-9 && abs(coverageRadius - 3) < 1e-9)
    }

    @Test("more than 10% left out caps a good result at limited, with a reason")
    func excludedCapsTheLevel() throws {
        let tooMany = makeReport(measured: 75, excluded: 25, coverage: 0.999)
        #expect(tooMany.verdictLevel == .limited && tooMany.isReliable)
        #expect(tooMany.excludedShare == 0.25)
        let sentence = " 25% of the scan was more than 5 mm from the reference shape and is not counted."
        #expect(tooMany.verdict.contains(sentence))
        #expect(tooMany.reasons.count == 1 && tooMany.reasons[0].hasPrefix("25% of the scan was left out"))
        #expect(!tooMany.verdict.contains("had no scan"))

        let none = makeReport(measured: 100, excluded: 0, coverage: 0.999)
        #expect(none.verdictLevel == .good && none.reasons.isEmpty && !none.verdict.contains("not counted"))
        // 0.4% is below the 0.5% worth mentioning.
        let few = makeReport(measured: 498, excluded: 2, coverage: 0.999)
        #expect(few.verdictLevel == .good && !few.verdict.contains("not counted"))
        // 8% is mentioned but within the 10% allowed for good.
        let some = makeReport(measured: 92, excluded: 8, coverage: 0.999)
        #expect(some.verdictLevel == .good && some.verdict.contains(" 8% of the scan was more than 5 mm"))

        let rule = ReliabilityRule()
        #expect(rule.excludedProblem(share: 0.10) == nil)
        #expect(rule.excludedProblem(share: 0.11)?.contains("more than the 10% allowed") == true)
    }

    @Test("low coverage is mentioned in the verdict, using the settings' distances")
    func uncoveredIsMentioned() throws {
        let report = makeReport(measured: 100, excluded: 0, coverage: 0.7)
        #expect(report.verdict.contains(" 30% of the reference had no scan within 3 mm."))
        #expect(report.uncoveredSentence == "30% of the reference had no scan within 3 mm.")
        #expect(abs(report.uncoveredShare - 0.3) < 1e-9)
        let custom = makeReport(
            measured: 80, excluded: 20, coverage: 0.996, inlierDistance: 0.0025, coverageRadius: 0.002)
        #expect(custom.verdict.contains(" 20% of the scan was more than 2.5 mm from the reference shape"))
        #expect(!custom.verdict.contains("had no scan"))
        #expect(AccuracyReporting.uncoveredSentence(share: 0.004, radius: 0.003) == nil)
        #expect(AccuracyText.shortMillimetres(5) == "5" && AccuracyText.shortMillimetres(2.5) == "2.5")
    }

    @Test("the full verdict says what was counted, in order")
    func fullWording() throws {
        let stats = try #require(DeviationStats([0.00062]))
        let overall = SizeClassResult(sizeClass: nil, label: AccuracyReporting.overallLabel, stats: stats)
        let small = SizeClassResult(sizeClass: .small, label: "Small", stats: try #require(DeviationStats([0.0009])))
        let large = SizeClassResult(sizeClass: .large, label: "Large", stats: try #require(DeviationStats([0.0004])))
        let text = AccuracyReporting.verdict(
            overall: overall, classes: [small, large], excludedShare: 0.12, uncoveredShare: 1 - 0.92)
        let expected =
            "The measured surface is within ±0.62 mm of the true shape for 95% of the points counted; "
            + "least accurate on small features (±0.90 mm). 12% of the scan was more than 5 mm from the "
            + "reference shape and is not counted. 8% of the reference had no scan within 3 mm. "
            + "These are surface distances, not feature sizes."
        #expect(text == expected)
    }

    @Test("a version 1 report still reads, with the counts unknown rather than zero")
    func versionOneReport() throws {
        let json =
            #"{"version":1,"scanID":"\#(UUID().uuidString)","createdAt":"2026-11-10T08:00:00Z","#
            + #""match":{"rmsMillimetres":0.3,"coverage":0.9,"inlierFraction":0.95,"iterations":12,"#
            + #""startsTried":36,"quality":"good"},"isReliable":true,"verdictLevel":"good","#
            + #""verdict":"The surface is within ±0.40 mm of the true shape for 95% of points.","reasons":[],"#
            + #""overall":{"label":"Whole surface","pointCount":900,"meanMillimetres":0.01,"rmsMillimetres":0.2,"#
            + #""within95Millimetres":0.4,"maximumMillimetres":0.9},"sizeClasses":[],"pointsUsed":1000}"#
        let report = try AccuracyReportCodec.decode(Data(json.utf8))
        #expect(report.version == 1 && report.isReliable && report.verdictLevel == .good)
        #expect(report.pointsMeasured == nil && report.pointsExcluded == nil && report.excludedShare == nil)
        #expect(report.excludedSentence == nil && report.uncoveredSentence == nil)
        #expect(report.overall?.label == "Measured surface" && report.overall?.pointCount == 900)
        let saved = try AccuracyReportCodec.decode(AccuracyReportCodec.encode(makeReport(measured: 9, excluded: 1)))
        #expect(saved.version == 2 && saved.pointsMeasured == 9 && saved.pointsExcluded == 1)
        let savedDistance = try #require(saved.inlierDistanceMillimetres)
        #expect(abs(savedDistance - 5) < 1e-9)
    }

    /// A report on a near-perfect fit with `measured` points counted (all 0.1 mm out)
    /// and `excluded` left out.
    private func makeReport(
        measured: Int, excluded: Int, coverage: Double = 0.95,
        inlierDistance: Double = 0.005, coverageRadius: Double = 0.003
    ) -> AccuracyReport {
        let stats = DeviationStats(Array(repeating: 0.0001, count: measured))
        let deviation = DeviationResult(
            overall: stats, bySizeClass: stats.map { [.large: $0] } ?? [:], otherSurface: nil, excluded: excluded)
        let alignment = AlignmentResult(
            transform: .identity, rmsResidual: 0.0001, inlierFraction: 0.9, coverage: coverage, iterations: 5,
            startsTried: 36)
        let context = ReportContext(
            scanID: UUID(), createdAt: Date(), table: AccuracyFixtures.table, inlierDistance: inlierDistance,
            coverageRadius: coverageRadius)
        return AccuracyReporting.makeReport(alignment: alignment, deviation: deviation, context: context)
    }
}
