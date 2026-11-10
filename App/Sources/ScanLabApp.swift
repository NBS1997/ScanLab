import ScanLabCore
import SwiftUI

@main
struct ScanLabApp: App {
    private let environment: AppEnvironment

    init() {
        environment = AppEnvironment.live()
        // Business rule BR-7: every launch is recorded with the version and build, so
        // an exported log always says which build produced it.
        environment.log.info(
            "app", "App launched",
            [
                "version": environment.buildInfo.version,
                "build": environment.buildInfo.build,
                "expires": environment.buildInfo.expiryDescription(now: Date()),
            ])
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(environment: environment)
        }
    }
}
