import Foundation
import Testing

@testable import ScanLabCore

@Suite("Log formatter")
struct LogFormatterTests {
    let event = LogEvent(
        timestamp: Date(timeIntervalSince1970: 0),
        level: .info,
        category: "app",
        message: "App launched",
        details: ["version": "0.1.0", "build": "1"]
    )

    @Test("a line holds time, level, category, message and sorted details")
    func line() {
        #expect(
            LogFormatter.line(for: event)
                == "1970-01-01T00:00:00.000Z  INFO     app  App launched  build=1 version=0.1.0")
    }

    @Test("an event without details has no trailing separator")
    func lineWithoutDetails() {
        var plain = event
        plain.details = [:]
        #expect(LogFormatter.line(for: plain).hasSuffix("App launched"))
    }

    @Test("exported text has a header, one line per event and a final newline")
    func text() {
        let text = LogFormatter.text(for: [event, event], unreadableLines: 0)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.first == "ScanLab diagnostics log — 2 events")
        #expect(text.hasSuffix("\n"))
        #expect(!text.contains("unreadable"))
        #expect(lines.filter { $0.contains("App launched") }.count == 2)
    }

    @Test("exported text mentions unreadable lines when there were any")
    func textWithUnreadable() {
        let text = LogFormatter.text(for: [], unreadableLines: 3)
        #expect(text.contains("3 unreadable line(s) were skipped"))
    }
}
