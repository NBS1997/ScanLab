import Testing

@testable import ScanLabCore

@Suite("Log trimmer")
struct LogTrimmerTests {
    private func lines(_ count: Int) -> String {
        (1...count).map { "line \($0)" }.joined(separator: "\n") + "\n"
    }

    @Test("a log within the limit is left alone")
    func withinLimit() {
        #expect(LogTrimmer.trimmed(lines(3), keepingLast: 3) == nil)
    }

    @Test("a log over the limit keeps only the newest lines")
    func overLimit() {
        #expect(LogTrimmer.trimmed(lines(5), keepingLast: 2) == "line 4\nline 5\n")
    }

    @Test("blank lines do not count towards the limit")
    func blankLinesIgnored() {
        #expect(LogTrimmer.trimmed("a\n\n\nb\n", keepingLast: 2) == nil)
        #expect(LogTrimmer.trimmed("a\n\nb\n\nc", keepingLast: 2) == "b\nc\n")
    }

    @Test("an empty log needs no trimming")
    func emptyLog() {
        #expect(LogTrimmer.trimmed("", keepingLast: 1) == nil)
    }

    @Test("the default limit meets the requirement of at least 1,000 lines")
    func defaultLimit() {
        #expect(LogTrimmer.defaultLimit >= 1_000)
        #expect(LogTrimmer.trimmed(lines(LogTrimmer.defaultLimit)) == nil)
        let trimmed = LogTrimmer.trimmed(lines(LogTrimmer.defaultLimit + 1))
        #expect(trimmed?.hasPrefix("line 2\n") == true)
    }
}
