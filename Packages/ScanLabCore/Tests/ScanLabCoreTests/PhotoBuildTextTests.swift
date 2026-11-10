import Foundation
import Testing

@testable import ScanLabCore

private let start = Date(timeIntervalSince1970: 1_794_405_930)

@Suite("Photo build text")
struct PhotoBuildTextTests {
    @Test("percent rounds down and is clamped")
    func percent() {
        let cases: [(Double, String)] = [
            (0.0, "0%"), (0.426, "42%"), (0.999, "99%"), (1.0, "100%"), (-0.5, "0%"), (3.0, "100%"), (.nan, "0%"),
        ]
        for (fraction, expected) in cases {
            #expect(PhotoBuildText.percent(fraction) == expected)
        }
    }

    @Test("headline, stage and spoken text")
    func headline() {
        let progress = BuildProgress(fraction: 0.42, stage: .makingMesh, secondsRemaining: 185, updatedAt: start)
        #expect(PhotoBuildText.headline(progress) == "Building model: 42%")
        #expect(PhotoBuildText.stage(.makingMesh) == "Now making the mesh")
        #expect(PhotoBuildText.stage(nil) == "Starting")
        #expect(PhotoBuildText.spoken(progress) == "42 percent, now making the mesh, about 3 min left")
        let early = BuildProgress(fraction: 0, updatedAt: start)
        #expect(PhotoBuildText.spoken(early) == "0 percent, starting")
    }

    @Test("every stage has words")
    func stages() {
        for stage in BuildStage.allCases {
            #expect(!stage.displayName.isEmpty)
            // Starts lower case, as it follows "Now " on screen.
            #expect(stage.displayName.first?.isLowercase == true)
        }
    }

    @Test("time left")
    func remaining() {
        #expect(PhotoBuildText.remaining(nil) == nil)
        #expect(PhotoBuildText.remaining(-1) == nil)
        #expect(PhotoBuildText.remaining(.infinity) == nil)
        #expect(PhotoBuildText.remaining(20) == "Less than a minute left")
        #expect(PhotoBuildText.remaining(70) == "About 1 min left")
        #expect(PhotoBuildText.remaining(600) == "About 10 min left")
    }

    @Test("still-working notice appears after 10 seconds without an update")
    func stale() {
        let progress = BuildProgress(fraction: 0.3, updatedAt: start)
        #expect(PhotoBuildText.staleNotice(progress, now: start.addingTimeInterval(9.9)) == nil)
        let notice = PhotoBuildText.staleNotice(progress, now: start.addingTimeInterval(10))
        #expect(notice == "Still working. Last update 10 s ago.")
        #expect(PhotoBuildText.staleNotice(progress, now: start.addingTimeInterval(-5)) == nil)
    }

    @Test("photo counts")
    func photos() {
        #expect(PhotoBuildText.photos(1) == "1 photo")
        #expect(PhotoBuildText.photos(64) == "64 photos")
        #expect(PhotoBuildText.photos(-2) == "0 photos")
    }

    @Test("the keep question names the storage used")
    func keep() {
        let offer = KeepOffer(scanID: UUID(), scanName: "Bracket", images: 64, rawBytes: 412_000_000)
        #expect(PhotoBuildText.keepTitle == "Keep the raw capture?")
        #expect(PhotoBuildText.keepMessage(offer).hasPrefix("The 64 photos and camera positions use 412 MB."))
        #expect(PhotoBuildText.keepButton(offer) == "Keep (412 MB)")
    }

    @Test("the closing message says what happened to the raw capture")
    func done() {
        let id = UUID()
        let kept = PhotoCaptureOutcome(scanID: id, scanName: "Bracket", keptRawBytes: 1_200_000_000)
        #expect(PhotoBuildText.done(kept) == "Saved \u{201C}Bracket\u{201D}. Raw capture kept (1.2 GB).")
        let dropped = PhotoCaptureOutcome(scanID: id, scanName: "Bracket", keptRawBytes: nil)
        #expect(PhotoBuildText.done(dropped) == "Saved \u{201C}Bracket\u{201D}. Raw capture discarded.")
    }

    @Test("detail level text and manifest values")
    func detail() {
        #expect(PhotoBuildText.detail(.reduced) == "Detail level: reduced (the only level iPhone offers)")
        #expect(PhotoBuildText.detail(.full) == "Detail level: full")
        #expect(PhotoDetailLevel.reduced.manifestValue == "reduced")
    }
}

@Suite("Photo capture errors")
struct PhotoCaptureErrorTests {
    @Test("every error has a message with a next step and a log name")
    func messages() {
        let all: [PhotoCaptureError] = [
            .unsupportedDevice, .cameraDenied, .tooFewImages(taken: 3, minimum: 10), .captureFailed("x"),
            .buildFailed("y"), .noModel, .noSpace, .fileFailed("z"), .cancelled,
        ]
        for error in all {
            #expect(!(error.errorDescription ?? "").isEmpty)
            #expect(!error.logName.isEmpty)
        }
        #expect(PhotoCaptureError.tooFewImages(taken: 3, minimum: 10).errorDescription?.contains("Only 3") == true)
        #expect(PhotoCaptureError.cameraDenied.errorDescription?.contains("Settings") == true)
    }

    @Test("store and file errors are translated, storage full included")
    func translate() {
        #expect(PhotoCaptureError.from(PhotoCaptureError.noModel) == .noModel)
        #expect(PhotoCaptureError.from(StoreError.noSpace) == .noSpace)
        #expect(fileReason(PhotoCaptureError.from(StoreError.notFound(UUID())))?.contains("could not be found") == true)
        let full = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        #expect(PhotoCaptureError.from(full) == .noSpace)
        let other = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        #expect(fileReason(PhotoCaptureError.from(other)) != nil)
        let malformed = PhotoCaptureError.from(MeshFileError.malformed(line: 2, reason: "bad"))
        #expect(fileReason(malformed)?.contains("Line 2") == true)
    }

    private func fileReason(_ error: PhotoCaptureError) -> String? {
        if case .fileFailed(let reason) = error { return reason }
        return nil
    }
}
