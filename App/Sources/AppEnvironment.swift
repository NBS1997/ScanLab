import Foundation
import ScanLabCore

/// The composition root: the one place that creates the real implementations of
/// Core's ports and hands them to the screens (components.md, "Composition").
/// Screens only ever see the protocols, so they can be previewed with fakes.
struct AppEnvironment: Sendable {
    let log: any Logging
    let buildInfo: BuildInfo

    /// The real app.
    static func live() -> AppEnvironment {
        AppEnvironment(
            log: FileLog(directory: FileLog.standardDirectory()),
            buildInfo: BuildInfo(infoDictionary: Bundle.main.infoDictionary ?? [:])
        )
    }

    /// For SwiftUI previews: an in-memory log and a fixed build date.
    static func preview() -> AppEnvironment {
        let log = MemoryLog()
        log.info("app", "App launched", ["version": "0.1.0", "build": "1"])
        log.warning("log", "Example warning")
        return AppEnvironment(
            log: log,
            buildInfo: BuildInfo(version: "0.1.0", build: "1", buildDate: Date().addingTimeInterval(-29 * 86_400))
        )
    }
}
