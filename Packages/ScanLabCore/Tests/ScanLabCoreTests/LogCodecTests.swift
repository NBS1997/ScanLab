import Foundation
import Testing

@testable import ScanLabCore

@Suite("Log codec")
struct LogCodecTests {
    let sample = LogEvent(
        timestamp: Date(timeIntervalSince1970: 1_794_306_127),
        level: .warning,
        category: "capture",
        message: "Tracking lost",
        details: ["seconds": "3", "method": "sweep"]
    )

    @Test("an encoded event decodes back to the same event")
    func roundTrip() throws {
        let line = try LogCodec.encode(sample)
        let result = LogCodec.decode(text: line + "\n")
        #expect(result.events == [sample])
        #expect(result.unreadableLines == 0)
    }

    @Test("an event whose message contains a newline still encodes to one line")
    func newlineStaysOnOneLine() throws {
        let event = LogEvent(category: "app", message: "first\nsecond")
        let line = try LogCodec.encode(event)
        #expect(!line.contains("\n"))
        #expect(LogCodec.decode(text: line).events.first?.message == "first\nsecond")
    }

    @Test("damaged lines are counted and skipped without losing the good ones")
    func damagedLinesAreSkipped() throws {
        let good = try LogCodec.encode(sample)
        let text = [good, "{not json", "", "   ", #"{"message":"missing fields"}"#, good].joined(separator: "\n")
        let result = LogCodec.decode(text: text)
        #expect(result.events.count == 2)
        #expect(result.unreadableLines == 2)
    }

    @Test("an empty file decodes to an empty result")
    func emptyFile() {
        #expect(LogCodec.decode(text: "") == LogReadResult())
    }

    @Test("a timestamp that is not ISO 8601 makes the line unreadable")
    func badTimestamp() {
        let line = #"{"category":"app","details":{},"level":"info","message":"m","timestamp":"yesterday"}"#
        let result = LogCodec.decode(text: line)
        #expect(result.events.isEmpty)
        #expect(result.unreadableLines == 1)
    }

    @Test("timestamps without fractional seconds are accepted")
    func plainTimestamp() {
        let line = #"{"category":"app","details":{},"level":"info","message":"m","timestamp":"2026-11-10T10:42:07Z"}"#
        let result = LogCodec.decode(text: line)
        #expect(result.events.count == 1)
    }

    @Test("an unknown level makes the line unreadable")
    func unknownLevel() {
        let line = #"{"category":"app","details":{},"level":"panic","message":"m","timestamp":"2026-11-10T10:42:07Z"}"#
        #expect(LogCodec.decode(text: line).unreadableLines == 1)
    }
}
