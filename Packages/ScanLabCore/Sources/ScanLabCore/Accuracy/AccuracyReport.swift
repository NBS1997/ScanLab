import Foundation

/// A stored accuracy report (FR-9.1–9.4, FR-9.6 by size class), saved as
/// `accuracy-report.json` in the scan's folder.
///
/// Like the scan manifest it is versioned and read forgivingly: fields added later
/// (stage 2 adds per-feature results and comparisons, unit U11) are ignored by older
/// builds, and fields missing from older reports take defaults.
public struct AccuracyReport: Equatable, Sendable {
    public static let currentVersion = 1

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
    /// Why the report is unreliable; empty when it is reliable.
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
        stepMilliseconds: [String: Int] = [:]
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
    }

    /// The headline, for example "Match good · 0.21 mm".
    public var matchLine: String {
        "Match \(match.quality.displayName) · \(AccuracyText.millimetres(match.rmsMillimetres)) mm"
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

    public init(
        scanID: UUID, createdAt: Date, table: FeatureTable, rule: ReliabilityRule = ReliabilityRule(),
        caliperValuesEntered: Int = 0
    ) {
        self.scanID = scanID
        self.createdAt = createdAt
        self.table = table
        self.rule = rule
        self.caliperValuesEntered = caliperValuesEntered
    }
}

/// Turns alignment and deviation results into a report (AccuracyReporting in
/// components.md), applying the reliability rule and writing the verdict.
public enum AccuracyReporting {
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
        guard reasons.isEmpty, let deviation, let overallStats = deviation.overall else {
            let extra = reasons.isEmpty ? ["No part of the scan lies close to the reference shape."] : reasons
            return AccuracyReport(
                scanID: context.scanID, createdAt: context.createdAt, match: match, verdictLevel: .unreliable,
                verdict: unreliableVerdict, reasons: extra, transform: numbers,
                caliperValuesEntered: context.caliperValuesEntered)
        }
        let overall = SizeClassResult(sizeClass: nil, label: "Whole surface", stats: overallStats)
        let classes = sizeClassRows(deviation, table: context.table)
        let level: VerdictLevel = overallStats.within95 <= rule.trustedSpread ? .good : .limited
        return AccuracyReport(
            scanID: context.scanID, createdAt: context.createdAt, match: match, verdictLevel: level,
            verdict: verdict(overall: overall, classes: classes), overall: overall, sizeClasses: classes,
            transform: numbers, caliperValuesEntered: context.caliperValuesEntered)
    }

    /// The verdict when no figures may be shown (FR-9.4).
    public static let unreliableVerdict =
        "Unreliable: this scan does not look like the reference object, so no accuracy figures are shown."

    /// One sentence from the figures, for example "The surface is within ±0.62 mm of
    /// the true shape for 95% of points; least accurate on small features (±0.91 mm).
    /// These are surface distances, not feature sizes."
    static func verdict(overall: SizeClassResult, classes: [SizeClassResult]) -> String {
        let spread = AccuracyText.millimetres(overall.within95Millimetres)
        var text = "The surface is within ±\(spread) mm of the true shape for 95% of points"
        let featureClasses = classes.filter { $0.sizeClass != nil }
        let worst = featureClasses.max { $0.within95Millimetres < $1.within95Millimetres }
        if featureClasses.count > 1, let worst, let name = worst.sizeClass?.displayName.lowercased() {
            let worstSpread = AccuracyText.millimetres(worst.within95Millimetres)
            text += "; least accurate on \(name) features (±\(worstSpread) mm)"
        }
        return text + ". These are surface distances, not feature sizes."
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
