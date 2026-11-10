import Foundation
import Testing

@testable import ScanLabCore

private let start = Date(timeIntervalSince1970: 1_794_405_930)

private func offer(images: Int = 40, bytes: Int64 = 400_000_000) -> KeepOffer {
    KeepOffer(scanID: UUID(), scanName: "Photos 11 Nov 14:05", images: images, rawBytes: bytes)
}

/// A flow already building, at 0%.
private func buildingFlow() -> PhotoCaptureFlow {
    var flow = PhotoCaptureFlow()
    flow.apply(.ready)
    flow.apply(.captureFinishing)
    flow.apply(.captureCompleted(images: 40))
    flow.apply(.buildStarted(time: start))
    return flow
}

@Suite("Photo capture flow")
struct PhotoCaptureFlowTests {
    @Test("the happy path: capture, build, save, keep")
    func happyPath() throws {
        var flow = PhotoCaptureFlow()
        #expect(flow.phase == .preparing)
        let step1 = flow.apply(.ready)
        #expect(step1)
        #expect(flow.phase == .capturing(shots: 0))
        let step2 = flow.apply(.shotsTaken(12))
        #expect(step2)
        #expect(flow.phase == .capturing(shots: 12))
        let step3 = flow.apply(.captureFinishing)
        #expect(step3)
        #expect(flow.phase == .finishingCapture)
        let step4 = flow.apply(.captureCompleted(images: 40))
        #expect(step4)
        #expect(flow.phase == .readyToBuild(images: 40))
        #expect(flow.canBuild)
        let step5 = flow.apply(.buildStarted(time: start))
        #expect(step5)
        #expect(flow.buildFraction == 0)
        let update = BuildUpdate(fraction: 0.5, stage: .makingMesh, secondsRemaining: 90)
        let step6 = flow.apply(.buildProgressed(update, time: start.addingTimeInterval(5)))
        #expect(step6)
        let expected = BuildProgress(
            fraction: 0.5, stage: .makingMesh, secondsRemaining: 90, updatedAt: start.addingTimeInterval(5))
        #expect(flow.phase == .building(expected))
        let step7 = flow.apply(.modelBuilt)
        #expect(step7)
        #expect(flow.phase == .saving)
        #expect(!flow.canCancel)
        let keep = offer()
        let step8 = flow.apply(.saved(keep))
        #expect(step8)
        #expect(flow.phase == .askingToKeep(keep))
        let step9 = flow.apply(.rawCaptureDecided(keep: true))
        #expect(step9)
        let outcome = PhotoCaptureOutcome(scanID: keep.scanID, scanName: keep.scanName, keptRawBytes: 400_000_000)
        #expect(flow.phase == .done(outcome))
        #expect(flow.isFinished)
    }

    @Test("discarding the raw capture records no kept bytes")
    func discard() {
        var flow = buildingFlow()
        flow.apply(.modelBuilt)
        let keep = offer()
        flow.apply(.saved(keep))
        flow.apply(.rawCaptureDecided(keep: false))
        let outcome = PhotoCaptureOutcome(scanID: keep.scanID, scanName: keep.scanName, keptRawBytes: nil)
        #expect(flow.phase == .done(outcome))
    }

    @Test("nothing to keep: done without asking")
    func nothingToKeep() {
        var flow = buildingFlow()
        flow.apply(.modelBuilt)
        let empty = offer(images: 0, bytes: 0)
        flow.apply(.saved(empty))
        let outcome = PhotoCaptureOutcome(scanID: empty.scanID, scanName: empty.scanName, keptRawBytes: nil)
        #expect(flow.phase == .done(outcome))
    }

    @Test("too few photographs fails and offers no build", arguments: [0, 3, PhotoCaptureFlow.minimumImages - 1])
    func tooFew(images: Int) {
        var flow = PhotoCaptureFlow()
        flow.apply(.ready)
        flow.apply(.captureCompleted(images: images))
        let error = PhotoCaptureError.tooFewImages(taken: images, minimum: PhotoCaptureFlow.minimumImages)
        #expect(flow.phase == .failed(error, canBuildAgain: false))
        #expect(!flow.canBuild)
        let step10 = flow.apply(.buildStarted(time: start))
        #expect(!step10)
    }

    @Test("exactly the minimum is enough")
    func minimumIsEnough() {
        var flow = PhotoCaptureFlow()
        flow.apply(.ready)
        flow.apply(.captureCompleted(images: PhotoCaptureFlow.minimumImages))
        #expect(flow.phase == .readyToBuild(images: PhotoCaptureFlow.minimumImages))
    }

    @Test("progress is clamped and never goes backwards; a missing stage keeps the last")
    func progressMonotonic() {
        var flow = buildingFlow()
        flow.apply(.buildProgressed(BuildUpdate(fraction: 0.6, stage: .aligningPhotos), time: start))
        flow.apply(.buildProgressed(BuildUpdate(fraction: 0.2), time: start.addingTimeInterval(1)))
        #expect(flow.buildFraction == 0.6)
        if case .building(let progress) = flow.phase {
            #expect(progress.stage == .aligningPhotos)
            #expect(progress.updatedAt == start.addingTimeInterval(1))
        } else {
            Issue.record("not building")
        }
        flow.apply(.buildProgressed(BuildUpdate(fraction: 7), time: start))
        #expect(flow.buildFraction == 1)
        flow.apply(.buildProgressed(BuildUpdate(fraction: .nan), time: start))
        #expect(flow.buildFraction == 1)
    }

    @Test("progress before building, or after cancelling, is refused")
    func progressRefused() {
        var flow = PhotoCaptureFlow()
        let step11 = flow.apply(.buildProgressed(BuildUpdate(fraction: 0.1), time: start))
        #expect(!step11)
        var building = buildingFlow()
        let step12 = building.apply(.cancelled)
        #expect(step12)
        #expect(building.phase == .cancelled(canBuildAgain: true))
        let step13 = building.apply(.buildProgressed(BuildUpdate(fraction: 0.5), time: start))
        #expect(!step13)
        let step14 = building.apply(.modelBuilt)
        #expect(!step14)
    }

    @Test("a failed build keeps the photographs and can be started again")
    func buildAgain() {
        var flow = buildingFlow()
        flow.apply(.buildProgressed(BuildUpdate(fraction: 0.4), time: start))
        let step15 = flow.apply(.failed(.buildFailed("GPU busy")))
        #expect(step15)
        #expect(flow.phase == .failed(.buildFailed("GPU busy"), canBuildAgain: true))
        #expect(flow.canBuild)
        let step16 = flow.apply(.buildStarted(time: start.addingTimeInterval(60)))
        #expect(step16)
        #expect(flow.buildFraction == 0)
    }

    @Test("running out of space while saving can be retried after freeing space")
    func noSpaceWhileSaving() {
        var flow = buildingFlow()
        flow.apply(.modelBuilt)
        flow.apply(.failed(.noSpace))
        #expect(flow.phase == .failed(.noSpace, canBuildAgain: true))
    }

    @Test("cancelling a capture before photographs are complete offers no build")
    func cancelCapture() {
        var flow = PhotoCaptureFlow()
        flow.apply(.ready)
        flow.apply(.shotsTaken(5))
        #expect(flow.canCancel)
        let step17 = flow.apply(.cancelled)
        #expect(step17)
        #expect(flow.phase == .cancelled(canBuildAgain: false))
        #expect(!flow.canBuild)
        let step18 = flow.apply(.cancelled)
        #expect(!step18)
    }

    @Test("an unsupported phone or refused camera fails at once, without a build offer")
    func unavailable() {
        var flow = PhotoCaptureFlow()
        let step19 = flow.apply(.failed(.cameraDenied))
        #expect(step19)
        #expect(flow.phase == .failed(.cameraDenied, canBuildAgain: false))
        let step20 = flow.apply(.failed(.unsupportedDevice))
        #expect(!step20)
        let step21 = flow.apply(.ready)
        #expect(!step21)
    }

    @Test("a sensor failure during capture offers no build")
    func captureFailure() {
        var flow = PhotoCaptureFlow()
        flow.apply(.ready)
        flow.apply(.failed(.captureFailed("sensor failed")))
        #expect(flow.phase == .failed(.captureFailed("sensor failed"), canBuildAgain: false))
    }

    @Test("an unfinished capture is picked up ready to build")
    func resumed() {
        var flow = PhotoCaptureFlow()
        let step22 = flow.apply(.resumed(images: 30))
        #expect(step22)
        #expect(flow.phase == .readyToBuild(images: 30))
        var empty = PhotoCaptureFlow()
        empty.apply(.resumed(images: 2))
        let error = PhotoCaptureError.tooFewImages(taken: 2, minimum: PhotoCaptureFlow.minimumImages)
        #expect(empty.phase == .failed(error, canBuildAgain: false))
    }

    @Test("failing to keep the raw capture does not offer to build a second scan")
    func keepFailure() {
        var flow = buildingFlow()
        flow.apply(.modelBuilt)
        flow.apply(.saved(offer()))
        #expect(!flow.canCancel)
        let step23 = flow.apply(.failed(.fileFailed("move failed")))
        #expect(step23)
        #expect(flow.phase == .failed(.fileFailed("move failed"), canBuildAgain: false))
        let step24 = flow.apply(.failed(.noSpace))
        #expect(!step24)
    }

    @Test("negative shot counts read as none; events out of place are refused")
    func oddEvents() {
        var flow = PhotoCaptureFlow()
        flow.apply(.ready)
        flow.apply(.shotsTaken(-4))
        #expect(flow.phase == .capturing(shots: 0))
        let step25 = flow.apply(.modelBuilt)
        #expect(!step25)
        let step26 = flow.apply(.rawCaptureDecided(keep: true))
        #expect(!step26)
        let step27 = flow.apply(.saved(offer()))
        #expect(!step27)
        #expect(flow.buildFraction == nil)
    }
}
