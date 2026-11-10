import Foundation

/// What a read of the log returns: the events that could be decoded, and how many
/// lines could not (business rule BR-3).
public struct LogReadResult: Equatable, Sendable {
    /// Events in the order they were written, oldest first.
    public var events: [LogEvent]
    /// Lines that were present but could not be decoded.
    public var unreadableLines: Int

    public init(events: [LogEvent] = [], unreadableLines: Int = 0) {
        self.events = events
        self.unreadableLines = unreadableLines
    }

    /// The most recent `limit` events, newest first, for showing on screen.
    public func newestFirst(limit: Int) -> [LogEvent] {
        Array(events.suffix(max(0, limit)).reversed())
    }
}

/// The port every part of the app uses to record what it does (ADR-011).
///
/// The app supplies the real implementation, which writes to a file on the phone.
/// Code in this package only ever sees this protocol, so it can be tested without
/// touching the file system.
public protocol Logging: Sendable {
    /// Records an event. Must never throw and never make the caller wait on disk
    /// (business rules BR-1 and BR-4).
    func log(_ event: LogEvent)

    /// Reads back everything currently in the log.
    func readAll() async -> LogReadResult
}

extension Logging {
    public func info(_ category: String, _ message: String, _ details: [String: String] = [:]) {
        log(LogEvent(level: .info, category: category, message: message, details: details))
    }

    public func warning(_ category: String, _ message: String, _ details: [String: String] = [:]) {
        log(LogEvent(level: .warning, category: category, message: message, details: details))
    }

    public func error(_ category: String, _ message: String, _ details: [String: String] = [:]) {
        log(LogEvent(level: .error, category: category, message: message, details: details))
    }

    /// The whole log as plain text, for the Export log button (BR-5).
    public func exportText() async -> String {
        let result = await readAll()
        return LogFormatter.text(for: result.events, unreadableLines: result.unreadableLines)
    }
}

/// A log kept in memory. Used by tests and by screen previews; the app itself uses
/// a file-backed log.
public final class MemoryLog: Logging, @unchecked Sendable {
    // @unchecked Sendable is safe here because every access to `events` goes
    // through `lock`.
    private let lock = NSLock()
    private var events: [LogEvent] = []

    public init(events: [LogEvent] = []) {
        self.events = events
    }

    public func log(_ event: LogEvent) {
        lock.withLock { events.append(event) }
    }

    public func readAll() async -> LogReadResult {
        lock.withLock { LogReadResult(events: events) }
    }
}
