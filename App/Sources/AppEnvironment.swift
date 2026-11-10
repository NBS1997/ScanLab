import Foundation
import ScanLabCore

/// The composition root: the one place that creates the real implementations of
/// Core's ports and hands them to the screens (components.md, "Composition").
/// Screens only ever see the protocols, so they can be previewed with fakes.
struct AppEnvironment: Sendable {
    let log: any Logging
    let buildInfo: BuildInfo
    /// The live camera and depth sensor (U06). It is shared: a screen starts it when
    /// it appears and stops it when it disappears.
    let sensorFeed: any LiveCameraFeeding
    /// The saved scans (LibraryService, unit U05): the single owner of scan data.
    let library: ScanLibrary
    /// Sweep capture with the depth sensor (U07). Shares the camera with Explore, so
    /// only one of them runs at a time.
    let sweepCapture: any LiveSweepCapturing

    /// The real app.
    @MainActor
    static func live() -> AppEnvironment {
        let log = FileLog(directory: FileLog.standardDirectory())
        let store = FileScanStore(root: FileScanStore.standardDirectory(), log: log)
        return AppEnvironment(
            log: log,
            buildInfo: BuildInfo(infoDictionary: Bundle.main.infoDictionary ?? [:]),
            sensorFeed: LiveSensorFeed(log: log),
            library: ScanLibrary(store: store, log: log, availableBytes: { store.availableCapacity() }),
            sweepCapture: ARKitSweepCapture(log: log)
        )
    }

    /// For SwiftUI previews: an in-memory log and library, a fixed build date and a
    /// made-up sensor.
    @MainActor
    static func preview() -> AppEnvironment {
        let log = MemoryLog()
        log.info("app", "App launched", ["version": "0.1.0", "build": "1"])
        log.warning("log", "Example warning")
        return AppEnvironment(
            log: log,
            buildInfo: BuildInfo(version: "0.1.0", build: "1", buildDate: Date().addingTimeInterval(-29 * 86_400)),
            sensorFeed: PreviewSensorFeed(),
            library: ScanLibrary(store: MemoryScanStore(), log: log),
            sweepCapture: PreviewSweepCapture()
        )
    }
}
