import Foundation

/// Turns events into lines of the log file and back.
///
/// Each event is stored as one line of JSON ("JSON Lines"). One line per event means
/// a crash can at worst damage the last line, and a damaged line can be skipped
/// without losing the rest (business rule BR-3).
public enum LogCodec {
    /// Errors that stop an event being stored.
    public enum CodecError: Error, Equatable {
        case notEncodable(String)
    }

    /// Encodes an event as a single line of JSON, without the trailing newline.
    public static func encode(_ event: LogEvent) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, container in
            var single = container.singleValueContainer()
            try single.encode(Timestamp.string(from: date))
        }
        let data: Data
        do {
            data = try encoder.encode(event)
        } catch {
            throw CodecError.notEncodable(String(describing: error))
        }
        // JSONEncoder escapes newlines inside strings, so the result is one line.
        guard let line = String(bytes: data, encoding: .utf8) else {
            throw CodecError.notEncodable("encoder output was not UTF-8")
        }
        return line
    }

    /// Decodes the whole contents of a log file. Blank lines are ignored; lines that
    /// are not valid events are counted in `unreadableLines` and otherwise skipped.
    public static func decode(text: String) -> LogReadResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { container in
            let single = try container.singleValueContainer()
            let raw = try single.decode(String.self)
            guard let date = Timestamp.date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: single, debugDescription: "Not an ISO 8601 timestamp: \(raw)")
            }
            return date
        }

        var result = LogReadResult()
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if let event = try? decoder.decode(LogEvent.self, from: Data(trimmed.utf8)) {
                result.events.append(event)
            } else {
                result.unreadableLines += 1
            }
        }
        return result
    }
}

/// ISO 8601 timestamps in UTC with milliseconds, e.g. `2026-11-10T10:42:07.123Z`.
enum Timestamp {
    private static let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt)
    private static let plainStyle = Date.ISO8601FormatStyle(timeZone: .gmt)

    static func string(from date: Date) -> String {
        date.formatted(style)
    }

    /// Accepts timestamps with or without fractional seconds.
    static func date(from string: String) -> Date? {
        (try? style.parse(string)) ?? (try? plainStyle.parse(string))
    }
}
