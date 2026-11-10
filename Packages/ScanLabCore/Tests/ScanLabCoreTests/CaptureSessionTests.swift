import Foundation
import Testing

@testable import ScanLabCore

@Suite("Capture session")
struct CaptureSessionTests {
    @Test("a capture runs from idle to saved")
    func happyPath() throws {
        var session = CaptureSession()
        let id = UUID()
        let phase1 = try session.apply(.start)
        #expect(phase1 == .preparing)
        let phase2 = try session.apply(.sensorReady)
        #expect(phase2 == .capturing)
        let phase3 = try session.apply(.finish)
        #expect(phase3 == .finishing)
        let phase4 = try session.apply(.saved(id))
        #expect(phase4 == .saved(id))
        #expect(session.phase.isOver)
    }

    @Test("Finish before the camera has started is refused and changes nothing")
    func finishTooEarly() throws {
        var session = CaptureSession()
        try session.apply(.start)
        #expect(!session.allows(.finish))
        #expect(throws: CaptureTransitionError(phase: .preparing, event: .finish)) {
            try session.apply(.finish)
        }
        #expect(session.phase == .preparing)
    }

    @Test("cancel is allowed until Finish, then refused")
    func cancelRules() throws {
        for setup in [[], [CaptureSessionEvent.start], [.start, .sensorReady]] {
            var session = CaptureSession()
            for event in setup {
                try session.apply(event)
            }
            let phase5 = try session.apply(.cancel)
            #expect(phase5 == .cancelled)
        }
        var finishing = CaptureSession(phase: .finishing)
        #expect(throws: CaptureTransitionError.self) { try finishing.apply(.cancel) }
        #expect(finishing.phase == .finishing)
    }

    @Test("a failure can happen while starting, capturing or saving, and Try again restarts")
    func failures() throws {
        for phase: CapturePhase in [.preparing, .capturing, .finishing] {
            var session = CaptureSession(phase: phase)
            let phase6 = try session.apply(.fail(.nothingCaptured))
            #expect(phase6 == .failed(.nothingCaptured))
            #expect(session.phase.isOver)
            let phase7 = try session.apply(.start)
            #expect(phase7 == .preparing)
        }
    }

    @Test("finished captures accept nothing more")
    func finalPhases() {
        let finals: [CapturePhase] = [.saved(UUID()), .cancelled]
        let events: [CaptureSessionEvent] = [.start, .sensorReady, .finish, .saved(UUID()), .fail(.noSpace), .cancel]
        for phase in finals {
            for event in events {
                #expect(!CaptureSession(phase: phase).allows(event))
            }
        }
        #expect(!CaptureSession().allows(.sensorReady))
        #expect(!CaptureSession(phase: .capturing).allows(.start))
    }

    @Test("phase and event names for the log")
    func logNames() {
        let phases: [CapturePhase] = [
            .idle, .preparing, .capturing, .finishing, .saved(UUID()), .failed(.noSpace), .cancelled,
        ]
        #expect(Set(phases.map(\.logName)).count == phases.count)
        let events: [CaptureSessionEvent] = [.start, .sensorReady, .finish, .saved(UUID()), .fail(.noSpace), .cancel]
        #expect(Set(events.map(\.logName)).count == events.count)
    }
}

@Suite("Capture errors")
struct CaptureErrorTests {
    @Test("library and other errors become capture errors")
    func wrapping() {
        #expect(CaptureError(wrapping: StoreError.noSpace) == .noSpace)
        #expect(CaptureError(wrapping: CaptureError.nothingCaptured) == .nothingCaptured)
        let write = CaptureError(wrapping: StoreError.writeFailed("disk busy"))
        guard case .saveFailed(let reason) = write else {
            Issue.record("expected saveFailed, got \(write)")
            return
        }
        #expect(reason.contains("disk busy"))
        guard case .buildFailed = CaptureError(wrapping: CocoaError(.fileReadUnknown)) else {
            Issue.record("expected buildFailed")
            return
        }
    }

    @Test("every error has a message saying what to do")
    func messages() {
        let errors: [CaptureError] = [
            .permissionDenied, .sensorUnavailable("No LiDAR here."), .sessionFailed("x"), .nothingCaptured,
            .noSpace, .saveFailed("Could not save."), .buildFailed("x"),
        ]
        for error in errors {
            let message = error.errorDescription ?? ""
            #expect(!message.isEmpty)
        }
        #expect(CaptureError.nothingCaptured.errorDescription?.contains("nothing was saved") == true)
        #expect(CaptureError.sensorUnavailable("No LiDAR here.").errorDescription == "No LiDAR here.")
    }
}
