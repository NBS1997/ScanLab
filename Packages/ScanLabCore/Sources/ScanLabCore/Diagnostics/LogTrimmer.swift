/// Keeps the log file from growing without limit (business rule BR-2).
public enum LogTrimmer {
    /// Lines kept after trimming. Requirement FR-10.2 asks for at least 1,000.
    public static let defaultLimit = 5_000

    /// Returns the text to keep — the last `limit` non-empty lines, each ending in a
    /// newline — or `nil` when the text is already within the limit and nothing needs
    /// rewriting.
    public static func trimmed(_ text: String, keepingLast limit: Int = defaultLimit) -> String? {
        precondition(limit > 0, "The log must keep at least one line")
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.isEmpty }
        guard lines.count > limit else { return nil }
        return lines.suffix(limit).joined(separator: "\n") + "\n"
    }
}
