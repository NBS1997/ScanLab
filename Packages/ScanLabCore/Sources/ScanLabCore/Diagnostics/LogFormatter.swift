import Foundation

/// Turns events into readable text, for the screen and for the exported log
/// (business rule BR-5).
public enum LogFormatter {
    /// One event on one line:
    /// `2026-11-10T10:42:07.123Z  INFO     app  App launched  build=1 version=0.1.0`
    public static func line(for event: LogEvent) -> String {
        let level = event.level.rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
        var parts = [Timestamp.string(from: event.timestamp), level, event.category, event.message]
        let details = detailsText(event.details)
        if !details.isEmpty { parts.append(details) }
        return parts.joined(separator: "  ")
    }

    /// Details as `key=value` pairs in alphabetical order, so the same event always
    /// prints the same way.
    public static func detailsText(_ details: [String: String]) -> String {
        details.keys.sorted().map { "\($0)=\(details[$0] ?? "")" }.joined(separator: " ")
    }

    /// The whole log as text, oldest first, with a note if any lines were unreadable.
    public static func text(for events: [LogEvent], unreadableLines: Int) -> String {
        var lines = ["ScanLab diagnostics log — \(events.count) events"]
        if unreadableLines > 0 {
            lines.append("Note: \(unreadableLines) unreadable line(s) were skipped.")
        }
        lines.append("")
        lines.append(contentsOf: events.map(line(for:)))
        return lines.joined(separator: "\n") + "\n"
    }
}
