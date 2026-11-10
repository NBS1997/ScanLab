import Foundation

/// How well the scan lined up with the reference, as a plain rating (FR-9.3).
public enum MatchQuality: String, Codable, Sendable {
    case good
    case fair
    case unreliable

    public var displayName: String {
        switch self {
        case .good: "good"
        case .fair: "fair"
        case .unreliable: "unreliable"
        }
    }
}

/// The verdict line's state (interaction-spec.md, Verdict line component).
public enum VerdictLevel: String, Codable, Sendable {
    case good
    case limited
    case unreliable
}

/// The alignment figures as stored in a report, in millimetres and shares (0 to 1).
public struct MatchSummary: Codable, Equatable, Sendable {
    public var rmsMillimetres: Double
    public var coverage: Double
    public var inlierFraction: Double
    public var iterations: Int
    public var startsTried: Int
    public var quality: MatchQuality

    public init(
        rmsMillimetres: Double, coverage: Double, inlierFraction: Double, iterations: Int = 0,
        startsTried: Int = 0, quality: MatchQuality = .unreliable
    ) {
        self.rmsMillimetres = rmsMillimetres
        self.coverage = coverage
        self.inlierFraction = inlierFraction
        self.iterations = iterations
        self.startsTried = startsTried
        self.quality = quality
    }
}

/// When a match is too poor to report figures (FR-9.4), and when it is good. The
/// numbers are the provisional thresholds of ADR-009, to be tuned on the phone.
///
/// A report is **unreliable** when any of these hold:
/// - less than 60% of the reference's visible surface has a scan point within 3 mm
///   (coverage): the scan does not show enough of the object, or shows another one;
/// - the scan surface is more than 2 mm from the reference on average (RMS of the
///   points within 5 mm): the shapes do not match closely;
/// - less than half of the (background-removed) scan lies within 5 mm of the
///   reference: most of what was scanned is something else.
///
/// Coverage is the decisive test for "another object": after trimming, almost any
/// shape can find *some* points close to the reference, but a different object cannot
/// cover most of it.
public struct ReliabilityRule: Equatable, Sendable {
    public var maximumResidual = 0.002
    public var minimumCoverage = 0.6
    public var minimumInlierFraction = 0.5
    /// A match at least this good on both counts is rated good rather than fair.
    public var goodResidual = 0.0005
    public var goodCoverage = 0.8
    /// The verdict is good (not limited) when 95% of points are within this, metres.
    public var trustedSpread = 0.001

    public init() {}

    /// Reasons the match is unreliable, in plain words; empty when it is usable.
    public func problems(rmsResidual: Double, coverage: Double, inlierFraction: Double) -> [String] {
        var reasons: [String] = []
        if coverage < minimumCoverage {
            reasons.append(
                "Only \(AccuracyText.percent(coverage)) of the reference object's surface was found in the scan; "
                    + "at least \(AccuracyText.percent(minimumCoverage)) is needed.")
        }
        if rmsResidual > maximumResidual {
            reasons.append(
                "After lining up, the surfaces are \(AccuracyText.millimetres(rmsResidual * 1000)) mm apart (RMS); "
                    + "at most \(AccuracyText.millimetres(maximumResidual * 1000)) mm is allowed.")
        }
        if inlierFraction < minimumInlierFraction {
            reasons.append(
                "Only \(AccuracyText.percent(inlierFraction)) of the scan lies close to the reference shape; "
                    + "at least \(AccuracyText.percent(minimumInlierFraction)) is needed.")
        }
        return reasons
    }

    public func quality(rmsResidual: Double, coverage: Double, inlierFraction: Double) -> MatchQuality {
        if !problems(rmsResidual: rmsResidual, coverage: coverage, inlierFraction: inlierFraction).isEmpty {
            return .unreliable
        }
        return rmsResidual <= goodResidual && coverage >= goodCoverage ? .good : .fair
    }
}

/// One line of the size-class table, in millimetres.
public struct SizeClassResult: Codable, Equatable, Sendable, Identifiable {
    /// `nil` for plain surface between the feature regions.
    public var sizeClass: SizeClass?
    /// For example "Small (up to 5 mm)".
    public var label: String
    public var pointCount: Int
    public var meanMillimetres: Double
    public var rmsMillimetres: Double
    public var within95Millimetres: Double
    public var maximumMillimetres: Double

    public var id: String { sizeClass?.rawValue ?? "other" }

    public init(sizeClass: SizeClass?, label: String, stats: DeviationStats) {
        self.sizeClass = sizeClass
        self.label = label
        pointCount = stats.count
        meanMillimetres = stats.mean * Units.millimetresPerMetre
        rmsMillimetres = stats.rms * Units.millimetresPerMetre
        within95Millimetres = stats.within95 * Units.millimetresPerMetre
        maximumMillimetres = stats.maximum * Units.millimetresPerMetre
    }
}

/// Number formatting for accuracy figures: always "." as the decimal point and the
/// Australian digit grouping, whatever the phone's region.
public enum AccuracyText {
    private static let australian = Locale(identifier: "en_AU")

    /// "0.21"
    public static func millimetres(_ value: Double, decimals: Int = 2) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(australian))
    }

    /// "+0.21" or "−0.21" (with a true minus sign).
    public static func signedMillimetres(_ value: Double) -> String {
        let size = millimetres(abs(value))
        if size == millimetres(0) { return size }
        return (value < 0 ? "\u{2212}" : "+") + size
    }

    /// "84%"
    public static func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }
}
