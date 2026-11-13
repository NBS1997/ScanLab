import Foundation
import Testing

@testable import ScanLabCore

struct PhotoSessionTrackerTests {
    /// Regression for build 8: the session was already ready when the screen started
    /// listening, so "ready" was never heard and the object was never looked for. The
    /// screen now reads the current state first; the listener may then report the same
    /// state again. Looking for the object must happen exactly once.
    @Test func readyReadThenHeardStartsDetectingOnce() {
        var tracker = PhotoSessionTracker()
        let read = tracker.observe(.ready)
        let heard = tracker.observe(.ready)
        #expect(read == .startDetecting)
        #expect(heard == nil)
        #expect(tracker.step == .lookingForObject)
    }

    @Test func aStateMissedByTheListenerIsStillActedOnWhenRead() {
        // Without reading the current state, a tracker that never hears "ready" stays
        // on "starting" for ever, which is what the owner saw.
        var silent = PhotoSessionTracker()
        #expect(silent.step == .starting)
        let action = silent.observe(.ready)
        #expect(action == .startDetecting)
    }

    @Test func theUsualOrderGivesTheUsualSteps() {
        var tracker = PhotoSessionTracker()
        let first = tracker.observe(.initialising)
        #expect(first == nil)
        #expect(tracker.step == .starting)
        _ = tracker.observe(.ready)
        let found = tracker.observe(.detecting)
        #expect(found == nil)
        #expect(tracker.step == .objectFound)
        _ = tracker.observe(.capturing)
        #expect(tracker.step == .capturing)
        let finishing = tracker.observe(.finishing)
        #expect(finishing == .captureFinishing)
        let completed = tracker.observe(.completed)
        #expect(completed == .captureCompleted)
    }

    @Test func failureIsReportedOnce() {
        var tracker = PhotoSessionTracker()
        let first = tracker.observe(.failed)
        let again = tracker.observe(.failed)
        #expect(first == .captureFailed)
        #expect(again == nil)
    }

    @Test func photoCountOnlyShowsOncePhotosAreTaken() {
        var tracker = PhotoSessionTracker()
        #expect(!tracker.showsPhotoCount)
        _ = tracker.observe(.ready)
        #expect(!tracker.showsPhotoCount)
        _ = tracker.observe(.detecting)
        #expect(!tracker.showsPhotoCount)
        _ = tracker.observe(.capturing)
        #expect(tracker.showsPhotoCount)
    }

    @Test func everyStepSaysWhatToDoNext() {
        var tracker = PhotoSessionTracker()
        #expect(tracker.instruction == "Starting the camera…")
        _ = tracker.observe(.ready)
        #expect(tracker.instruction.contains("Find object"))
        _ = tracker.observe(.detecting)
        #expect(tracker.instruction.contains("Start capture"))
        _ = tracker.observe(.capturing)
        #expect(tracker.instruction.contains("on their own"))
        _ = tracker.observe(.finishing)
        #expect(tracker.instruction == "Saving the last photos…")
    }

    @Test func statesHaveLogNames() {
        let states: [PhotoSessionState] = [
            .initialising, .ready, .detecting, .capturing, .finishing, .completed, .failed,
        ]
        #expect(Set(states.map(\.logName)).count == states.count)
    }
}
