import Foundation

/// How serious a diagnostics event is.
public enum LogLevel: String, Codable, Sendable, CaseIterable {
    case info
    case warning
    case error
}

/// One entry in the diagnostics log.
///
/// An event records *what the app did*, never the content it handled: no file
/// contents, photographs or secrets belong in `message` or `details` (ADR-011).
public struct LogEvent: Codable, Equatable, Sendable {
    /// When the event happened, in UTC.
    public var timestamp: Date
    public var level: LogLevel
    /// The area of the app, such as `app`, `log` or `build`.
    public var category: String
    /// A short plain-English description.
    public var message: String
    /// Small pieces of context, such as counts, durations or error reasons.
    public var details: [String: String]

    public init(
        timestamp: Date = Date(),
        level: LogLevel = .info,
        category: String,
        message: String,
        details: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.details = details
    }
}
