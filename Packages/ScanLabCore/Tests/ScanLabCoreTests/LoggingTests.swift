import Foundation
import Testing

@testable import ScanLabCore

@Suite("Logging port and memory log")
struct LoggingTests {
    @Test("convenience methods record the right level, category and details")
    func convenienceLevels() async {
        let log = MemoryLog()
        log.info("app", "started", ["a": "1"])
        log.warning("log", "slow")
        log.error("build", "failed")
        let events = await log.readAll().events
        #expect(events.map(\.level) == [.info, .warning, .error])
        #expect(events.map(\.category) == ["app", "log", "build"])
        #expect(events.first?.details == ["a": "1"])
    }

    @Test("exportText formats everything in the log")
    func exportText() async {
        let log = MemoryLog(events: [LogEvent(category: "app", message: "one")])
        log.info("app", "two")
        let text = await log.exportText()
        #expect(text.contains("2 events"))
        #expect(text.contains("one"))
        #expect(text.contains("two"))
    }

    @Test("newestFirst returns the most recent events in reverse order")
    func newestFirst() {
        let events = (1...5).map { LogEvent(category: "t", message: "\($0)") }
        let result = LogReadResult(events: events)
        #expect(result.newestFirst(limit: 2).map(\.message) == ["5", "4"])
        #expect(result.newestFirst(limit: 10).count == 5)
        #expect(result.newestFirst(limit: -1).isEmpty)
    }

    @Test("concurrent writes are all kept")
    func concurrentWrites() async {
        let log = MemoryLog()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<200 {
                group.addTask { log.info("t", "\(index)") }
            }
        }
        #expect(await log.readAll().events.count == 200)
    }
}
