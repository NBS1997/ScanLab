import Foundation
import OSLog
import ScanLabCore

/// The real diagnostics log: one JSON line per event in a file on the phone
/// (ADR-011), mirrored to the system log.
///
/// How it avoids making callers wait: `log` puts each event on a queue (an
/// `AsyncStream`) and returns at once. A single background task takes events off the
/// queue in order and hands them to `FileLogStore`, which does the disk work. One
/// consumer means events are written in exactly the order they were logged.
final class FileLog: Logging {
    private let store: FileLogStore
    private let queue: AsyncStream<LogEvent>.Continuation
    private let systemLog = Logger(subsystem: "com.nbs1997.scanlab", category: "diagnostics")

    /// - Parameter directory: where `scanlab.log` lives. Created if missing.
    init(directory: URL) {
        let store = FileLogStore(fileURL: directory.appending(path: "scanlab.log"))
        let (stream, continuation) = AsyncStream.makeStream(of: LogEvent.self)
        self.store = store
        self.queue = continuation
        Task.detached(priority: .utility) {
            await store.prepare()
            for await event in stream {
                await store.append(event)
            }
        }
    }

    /// The standard location: Application Support/Logs inside the app's own storage.
    static func standardDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Logs", directoryHint: .isDirectory)
    }

    func log(_ event: LogEvent) {
        queue.yield(event)
        let line = LogFormatter.line(for: event)
        switch event.level {
        case .info: systemLog.info("\(line, privacy: .public)")
        case .warning: systemLog.warning("\(line, privacy: .public)")
        case .error: systemLog.error("\(line, privacy: .public)")
        }
    }

    func readAll() async -> LogReadResult {
        await store.read()
    }
}

/// Does the file work for `FileLog`. Being an actor means only one read or write
/// touches the file at a time.
actor FileLogStore {
    private let fileURL: URL
    /// Writes that failed since the last successful one (business rule BR-4).
    private var failedWrites = 0
    private var lastFailure = ""
    /// Set if the log could not be read, so the screen can say why.
    private(set) var lastReadError: String?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Runs once at launch: makes sure the folder exists and trims the file to the
    /// newest 5,000 lines (BR-2).
    func prepare() {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            recordFailure("could not create log folder: \(error.localizedDescription)")
            return
        }
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            if let kept = LogTrimmer.trimmed(text) {
                // Write the kept lines to a new file, then swap it in, so a crash
                // mid-trim never leaves a half-written log.
                try Data(kept.utf8).write(to: fileURL, options: .atomic)
            }
        } catch {
            recordFailure("could not trim log: \(error.localizedDescription)")
        }
    }

    func append(_ event: LogEvent) {
        if failedWrites > 0 {
            // Report earlier failures as soon as writing works again (BR-4).
            let note = LogEvent(
                level: .warning, category: "log", message: "Some log entries could not be saved",
                details: ["count": String(failedWrites), "reason": lastFailure])
            failedWrites = 0
            write(note)
        }
        write(event)
    }

    private func write(_ event: LogEvent) {
        do {
            let line = try LogCodec.encode(event) + "\n"
            if !FileManager.default.fileExists(atPath: fileURL.path()) {
                FileManager.default.createFile(atPath: fileURL.path(), contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            // Push the bytes to storage now, so the entry survives a crash (BR-1).
            try handle.synchronize()
        } catch {
            recordFailure(error.localizedDescription)
        }
    }

    func read() -> LogReadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return LogReadResult() }
        do {
            lastReadError = nil
            return LogCodec.decode(text: try String(contentsOf: fileURL, encoding: .utf8))
        } catch {
            lastReadError = error.localizedDescription
            return LogReadResult()
        }
    }

    private func recordFailure(_ reason: String) {
        failedWrites += 1
        lastFailure = reason
    }
}
