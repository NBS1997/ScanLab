import Foundation

/// A stored accuracy report (FR-9.1–9.4, FR-9.6 by size class), saved as
/// `accuracy-report.json` in the scan's folder.
///
/// Like the scan manifest it is versioned and read forgivingly: fields added later
/// (stage 2 adds per-feature results and comparisons, unit U11) are ignored by older
/// builds, and fields missing from older reports take defaults.
public struct AccuracyReport: Equatable, Sendable {
    /// Version 2 added the counts of points measured and left out, and the distances
    /// used, so the report can say what it counted.
    public static let currentVersion = 2

    public var version: Int
    public var scanID: UUID
    public var createdAt: Date
    public var match: MatchSummary
    /// Whether figures may be shown (FR-9.4). When false, `overall` is `nil` and
    /// `sizeClasses` is empty, so no figures can be shown by mistake.
    public var isReliable: Bool
    public var verdictLevel: VerdictLevel
    /// One sentence leading the report.
    public var verdict: String
    /// Why the report is unreliable, or why a reliable report is rated only limited
    /// rather than good; empty when neither applies.
    public var reasons: [String]
    public var overall: SizeClassResult?
    /// Small, medium and large (those with points), then plain surface.
    public var sizeClasses: [SizeClassResult]
    /// The alignment found, scan to reference: nine rotation numbers row by row, then
    /// the move in metres. Kept so stage 2 can measure features without aligning again.
    public var transform: [Double]
    /// Points the scan was turned into, and how many of those were removed as
    /// background before alignment.
    public var pointsUsed: Int
    public var backgroundRemoved: Int
    /// How many caliper values had been entered when the report was made.
    public var caliperValuesEntered: Int
    /// Aligned scan points that were close enough to the reference to be counted in the
    /// figures, and those further than the inlier distance that were left out. `nil` in
    /// reports made before version 2, when the counts were not kept (unknown, not zero).
    public var pointsMeasured: Int?
    public var pointsExcluded: Int?
    /// The distances behind those counts and the coverage figure, in millimetres:
    /// points further than `inlierDistanceMillimetres` are left out, and reference
    /// surface with no scan point within `coverageRadiusMillimetres` is uncovered.
    /// `nil` in reports made before version 2.
    public var inlierDistanceMillimetres: Double?
    public var coverageRadiusMillimetres: Double?
    /// How long each step took, in milliseconds, for Diagnostics.
    public var stepMilliseconds: [String: Int]

    public init(
        scanID: UUID,
        createdAt: Date,
        match: MatchSummary,
        verdictLevel: VerdictLevel,
        verdict: String,
        reasons: [String] = [],
        overall: SizeClassResult? = nil,
        sizeClasses: [SizeClassResult] = [],
        transform: [Double] = [],
        pointsUsed: Int = 0,
        backgroundRemoved: Int = 0,
        caliperValuesEntered: Int = 0,
        stepMilliseconds: [String: Int] = [:],
        pointsMeasured: Int? = nil,
        pointsExcluded: Int? = nil,
        inlierDistanceMillimetres: Double? = nil,
        coverageRadiusMillimetres: Double? = nil
    ) {
        self.version = Self.currentVersion
        self.scanID = scanID
        self.createdAt = createdAt
        self.match = match
        self.isReliable = verdictLevel != .unreliable
        self.verdictLevel = verdictLevel
        self.verdict = verdict
        self.reasons = reasons
        self.overall = overall
        self.sizeClasses = sizeClasses
        self.transform = transform
        self.pointsUsed = pointsUsed
        self.backgroundRemoved = backgroundRemoved
        self.caliperValuesEntered = caliperValuesEntered
        self.stepMilliseconds = stepMilliseconds
        self.pointsMeasured = pointsMeasured
        self.pointsExcluded = pointsExcluded
        self.inlierDistanceMillimetres = inlierDistanceMillimetres
        self.coverageRadiusMillimetres = coverageRadiusMillimetres
    }

    /// The headline, for example "Match good · 0.21 mm".
    public var matchLine: String {
        "Match \(match.quality.displayName) · \(AccuracyText.millimetres(match.rmsMillimetres)) mm"
    }

    /// The share of the aligned scan left out of the figures (0 to 1), or `nil` when
    /// the counts are unknown (a report from before version 2).
    public var excludedShare: Double? {
        guard let pointsMeasured, let pointsExcluded, pointsMeasured + pointsExcluded > 0 else { return nil }
        return Double(pointsExcluded) / Double(pointsMeasured + pointsExcluded)
    }

    /// The share of the reference's visible surface with no scan point nearby (0 to 1).
    public var uncoveredShare: Double {
        min(max(1 - match.coverage, 0), 1)
    }

    /// The verdict's sentence about points left out, or `nil` when too few were left
    /// out to mention or the counts are unknown.
    public var excludedSentence: String? {
        guard let excludedShare, let inlierDistanceMillimetres else { return nil }
        let distance = inlierDistanceMillimetres / Units.millimetresPerMetre
        return AccuracyReporting.excludedSentence(share: excludedShare, inlierDistance: distance)
    }

    /// The verdict's sentence about reference surface the scan did not reach, or `nil`
    /// when too little was missed to mention (or the radius is unknown).
    public var uncoveredSentence: String? {
        guard let coverageRadiusMillimetres else { return nil }
        let radius = coverageRadiusMillimetres / Units.millimetresPerMetre
        return AccuracyReporting.uncoveredSentence(share: uncoveredShare, radius: radius)
    }
}

extension AccuracyReport: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case scanID
        case createdAt
        case match
        case isReliable
        case verdictLevel
        case verdict
        case reasons
        case overall
        case sizeClasses
        case transform
        case pointsUsed
        case backgroundRemoved
        case caliperValuesEntered
        case stepMilliseconds
        case pointsMeasured
        case pointsExcluded
        case inlierDistanceMillimetres
        case coverageRadiusMillimetres
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        scanID = try container.decode(UUID.self, forKey: .scanID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        match = try container.decode(MatchSummary.self, forKey: .match)
        isReliable = try container.decodeIfPresent(Bool.self, forKey: .isReliable) ?? false
        verdictLevel = try container.decodeIfPresent(VerdictLevel.self, forKey: .verdictLevel) ?? .unreliable
        verdict = try container.decodeIfPresent(String.self, forKey: .verdict) ?? ""
        reasons = try container.decodeIfPresent([String].self, forKey: .reasons) ?? []
        // Figures are only ever read back for a reliable report (FR-9.4).
        if isReliable {
            overall = try container.decodeIfPresent(SizeClassResult.self, forKey: .overall)
            // Version 1 called this row "Whole surface", which it never was: points more
            // than the inlier distance away were always left out.
            if overall?.label == "Whole surface" {
                overall?.label = AccuracyReporting.overallLabel
            }
            sizeClasses = try container.decodeIfPresent([SizeClassResult].self, forKey: .sizeClasses) ?? []
        } else {
            overall = nil
            sizeClasses = []
        }
        transform = try container.decodeIfPresent([Double].self, forKey: .transform) ?? []
        pointsUsed = try container.decodeIfPresent(Int.self, forKey: .pointsUsed) ?? 0
        backgroundRemoved = try container.decodeIfPresent(Int.self, forKey: .backgroundRemoved) ?? 0
        caliperValuesEntered = try container.decodeIfPresent(Int.self, forKey: .caliperValuesEntered) ?? 0
        stepMilliseconds = try container.decodeIfPresent([String: Int].self, forKey: .stepMilliseconds) ?? [:]
        pointsMeasured = try container.decodeIfPresent(Int.self, forKey: .pointsMeasured)
        pointsExcluded = try container.decodeIfPresent(Int.self, forKey: .pointsExcluded)
        inlierDistanceMillimetres = try container.decodeIfPresent(Double.self, forKey: .inlierDistanceMillimetres)
        coverageRadiusMillimetres = try container.decodeIfPresent(Double.self, forKey: .coverageRadiusMillimetres)
    }
}

/// Turns reports into JSON and back, with dates as ISO 8601 text.
public enum AccuracyReportCodec {
    public static func encode(_ report: AccuracyReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(report)
        } catch {
            throw StoreError.writeFailed("the accuracy report could not be encoded")
        }
    }

    public static func decode(_ data: Data) throws -> AccuracyReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(AccuracyReport.self, from: data)
        } catch {
            throw StoreError.corrupt("the accuracy report could not be read")
        }
    }
}

/// What goes into a report besides the measurements.
public struct ReportContext: Sendable {
    public var scanID: UUID
    public var createdAt: Date
    public var table: FeatureTable
    public var rule: ReliabilityRule
    public var caliperValuesEntered: Int
    /// The alignment's distances, metres: points further than `inlierDistance` are left
    /// out of the figures; coverage counts reference surface within `coverageRadius`.
    public var inlierDistance: Double
    public var coverageRadius: Double

    public init(
        scanID: UUID, createdAt: Date, table: FeatureTable, rule: ReliabilityRule = ReliabilityRule(),
        caliperValuesEntered: Int = 0, inlierDistance: Double = AlignmentSettings().inlierDistance,
        coverageRadius: Double = AlignmentSettings().coverageRadius
    ) {
        self.scanID = scanID
        self.createdAt = createdAt
        self.table = table
        self.rule = rule
        self.caliperValuesEntered = caliperValuesEntered
        self.inlierDistance = inlierDistance
        self.coverageRadius = coverageRadius
    }
}

/// Turns alignment and deviation results into a report (AccuracyReporting in
/// components.md), applying the reliability rule and writing the verdict.
public enum AccuracyReporting {
    /// The overall row's label. Only points within the inlier distance are counted, so
    /// it is the measured surface, not the whole of it (business rule AC-14).
    public static let overallLabel = "Measured surface"

    /// Shares smaller than this (0.5%) are not worth a sentence in the verdict.
    public static let smallestShareMentioned = 0.005

    public static func makeReport(
        alignment: AlignmentResult, deviation: DeviationResult?, context: ReportContext
    ) -> AccuracyReport {
        let rule = context.rule
        let reasons = rule.problems(
            rmsResidual: alignment.rmsResidual, coverage: alignment.coverage, inlierFraction: alignment.inlierFraction)
        let quality = rule.quality(
            rmsResidual: alignment.rmsResidual, coverage: alignment.coverage, inlierFraction: alignment.inlierFraction)
        let match = MatchSummary(
            rmsMillimetres: alignment.rmsResidual * Units.millimetresPerMetre, coverage: alignment.coverage,
            inlierFraction: alignment.inlierFraction, iterations: alignment.iterations,
            startsTried: alignment.startsTried, quality: quality)
        let transform = alignment.transform
        let parts = [transform.xRow, transform.yRow, transform.zRow, transform.translation]
        let numbers = parts.flatMap { [$0.x, $0.y, $0.z] }
        var report = AccuracyReport(
            scanID: context.scanID, createdAt: context.createdAt, match: match, verdictLevel: .unreliable,
            verdict: unreliableVerdict, transform: numbers, caliperValuesEntered: context.caliperValuesEntered,
            pointsMeasured: deviation.map { $0.overall?.count ?? 0 }, pointsExcluded: deviation?.excluded,
            inlierDistanceMillimetres: context.inlierDistance * Units.millimetresPerMetre,
            coverageRadiusMillimetres: context.coverageRadius * Units.millimetresPerMetre)
        guard reasons.isEmpty, let deviation, let overallStats = deviation.overall else {
            report.reasons = reasons.isEmpty ? ["No part of the scan lies close to the reference shape."] : reasons
            return report
        }
        let overall = SizeClassResult(sizeClass: nil, label: overallLabel, stats: overallStats)
        let classes = sizeClassRows(deviation, table: context.table)
        var level: VerdictLevel = overallStats.within95 <= rule.trustedSpread ? .good : .limited
        // Points left out of the figures can only make them look better, so when a lot
        // were left out the result cannot be rated good, however small the figures.
        if let share = report.excludedShare, let problem = rule.excludedProblem(share: share) {
            level = .limited
            report.reasons = [problem]
        }
        report.isReliable = true
        report.verdictLevel = level
        report.overall = overall
        report.sizeClasses = classes
        report.verdict = verdict(
            overall: overall, classes: classes, excludedShare: report.excludedShare ?? 0,
            uncoveredShare: report.uncoveredShare, inlierDistance: context.inlierDistance,
            coverageRadius: context.coverageRadius)
        return report
    }

    /// The verdict when no figures may be shown (FR-9.4).
    public static let unreliableVerdict =
        "Unreliable: this scan does not look like the reference object, so no accuracy figures are shown."

    /// The verdict from the figures, saying what was counted, for example "The measured
    /// surface is within ±0.62 mm of the true shape for 95% of the points counted; least
    /// accurate on small features (±0.91 mm). 12% of the scan was more than 5 mm from
    /// the reference shape and is not counted. 8% of the reference had no scan within
    /// 3 mm. These are surface distances, not feature sizes."
    ///
    /// The two middle sentences appear only when their share is at least 0.5%.
    static func verdict(
        overall: SizeClassResult, classes: [SizeClassResult], excludedShare: Double = 0, uncoveredShare: Double = 0,
        inlierDistance: Double = AlignmentSettings().inlierDistance,
        coverageRadius: Double = AlignmentSettings().coverageRadius
    ) -> String {
        let spread = AccuracyText.millimetres(overall.within95Millimetres)
        var text = "The measured surface is within ±\(spread) mm of the true shape for 95% of the points counted"
        let featureClasses = classes.filter { $0.sizeClass != nil }
        let worst = featureClasses.max { $0.within95Millimetres < $1.within95Millimetres }
        if featureClasses.count > 1, let worst, let name = worst.sizeClass?.displayName.lowercased() {
            let worstSpread = AccuracyText.millimetres(worst.within95Millimetres)
            text += "; least accurate on \(name) features (±\(worstSpread) mm)"
        }
        text += "."
        if let excluded = excludedSentence(share: excludedShare, inlierDistance: inlierDistance) {
            text += " " + excluded
        }
        if let uncovered = uncoveredSentence(share: uncoveredShare, radius: coverageRadius) {
            text += " " + uncovered
        }
        return text + " These are surface distances, not feature sizes."
    }

    /// "12% of the scan was more than 5 mm from the reference shape and is not
    /// counted.", or `nil` below 0.5%. `inlierDistance` is in metres.
    public static func excludedSentence(share: Double, inlierDistance: Double) -> String? {
        guard share >= smallestShareMentioned else { return nil }
        let distance = AccuracyText.shortMillimetres(inlierDistance * Units.millimetresPerMetre)
        return "\(AccuracyText.percent(share)) of the scan was more than \(distance) mm from the reference shape "
            + "and is not counted."
    }

    /// "8% of the reference had no scan within 3 mm.", or `nil` below 0.5%. `radius`
    /// is in metres.
    public static func uncoveredSentence(share: Double, radius: Double) -> String? {
        guard share >= smallestShareMentioned else { return nil }
        let distance = AccuracyText.shortMillimetres(radius * Units.millimetresPerMetre)
        return "\(AccuracyText.percent(share)) of the reference had no scan within \(distance) mm."
    }

    private static func sizeClassRows(_ deviation: DeviationResult, table: FeatureTable) -> [SizeClassResult] {
        var rows = SizeClass.allCases.compactMap { sizeClass in
            deviation.bySizeClass[sizeClass].map {
                SizeClassResult(sizeClass: sizeClass, label: table.label(for: sizeClass), stats: $0)
            }
        }
        if let other = deviation.otherSurface {
            rows.append(SizeClassResult(sizeClass: nil, label: "Rest of the surface", stats: other))
        }
        return rows
    }
}
