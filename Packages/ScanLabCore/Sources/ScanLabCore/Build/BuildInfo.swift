import Foundation

/// Which build of the app is running, and when its TestFlight copy stops working.
///
/// TestFlight builds stop opening 90 days after upload (platform verification V8).
/// The build date is written into the app when it is built; from that we work out how
/// many days are left (requirement FR-1.3, business rule BR-6).
public struct BuildInfo: Equatable, Sendable {
    public static let testFlightLifetimeDays = 90
    private static let secondsPerDay: TimeInterval = 86_400

    public var version: String
    public var build: String
    /// `nil` when the build date was not stamped, e.g. in a screen preview.
    public var buildDate: Date?

    public init(version: String, build: String, buildDate: Date?) {
        self.version = version
        self.build = build
        self.buildDate = buildDate
    }

    /// Reads the values the app finds in its Info.plist. Missing values become
    /// "unknown" rather than failing, so the Diagnostics screen always opens.
    public init(infoDictionary: [String: Any]) {
        self.init(
            version: infoDictionary["CFBundleShortVersionString"] as? String ?? "unknown",
            build: infoDictionary["CFBundleVersion"] as? String ?? "unknown",
            buildDate: Self.parseBuildDate(infoDictionary["SLBuildDate"] as? String)
        )
    }

    /// "0.1.0 (27)"
    public var versionDescription: String { "\(version) (\(build))" }

    /// 90 days after the build date. Measured in exact days, not calendar days, so time
    /// zones and daylight saving make no difference.
    public var expiryDate: Date? {
        buildDate?.addingTimeInterval(Double(Self.testFlightLifetimeDays) * Self.secondsPerDay)
    }

    /// Whole days left before the build expires; never negative.
    public func daysUntilExpiry(now: Date) -> Int? {
        guard let expiryDate else { return nil }
        let remaining = expiryDate.timeIntervalSince(now)
        return remaining <= 0 ? 0 : Int(remaining / Self.secondsPerDay)
    }

    /// The text shown on the Diagnostics screen.
    public func expiryDescription(now: Date) -> String {
        guard let expiryDate, let days = daysUntilExpiry(now: now) else {
            return "unknown (no build date)"
        }
        if expiryDate <= now { return "expired" }
        switch days {
        case 0: return "today"
        case 1: return "in 1 day"
        default: return "in \(days) days"
        }
    }

    /// Accepts the `yyyy-MM-ddTHH:mm:ssZ` form the build stamps; anything else is `nil`.
    public static func parseBuildDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return Timestamp.date(from: string)
    }
}
