import Foundation
import Observation
import RealityKit
import ScanLabCore
import SwiftUI
import UIKit

/// What the photo capture screen shows (US-07, FR-4, FR-6.6), kept apart from the view.
///
/// The steps are: check the phone and camera → guided capture with Apple's Object
/// Capture → build the model on the phone with progress → read it into a Core mesh,
/// turn it z-up and save it to the library → ask whether to keep the raw capture.
/// Core's `PhotoCaptureFlow` decides which step may follow which; this model drives
/// the platform and writes every step to the diagnostics log (category `photo`).
@MainActor
@Observable
final class PhotoCaptureModel {
    private(set) var flow = PhotoCaptureFlow()
    /// The platform's capture session while photographs are being taken; `nil`
    /// otherwise, so the camera is released before building (Apple's advice: building
    /// needs the memory).
    private(set) var session: ObjectCaptureSession?
    /// Follows the platform's capture state (Core's `PhotoSessionTracker`).
    private(set) var tracker = PhotoSessionTracker()
    var step: PhotoGuidedStep { tracker.step }
    /// Set when the platform could not find a flat surface under the object.
    private(set) var detectHint: String?
    /// The platform's current advice, for example "Move slower".
    private(set) var feedbackText: String?
    /// True once the owner has gone all the way round the object.
    private(set) var scanPassComplete = false
    /// A capture left from earlier (for example the app was closed mid-build).
    private(set) var unfinished: UnfinishedCapture?
    /// What happened while the app was in the background during a build.
    var backgroundNote: String?
    /// Set when the capture folder has been removed, so no Discard button is shown.
    var captureDiscarded = false

    @ObservationIgnored let capture: any PhotoCapturing
    @ObservationIgnored let library: ScanLibrary
    @ObservationIgnored let log: any Logging
    @ObservationIgnored let root: URL
    @ObservationIgnored var folders: RawCaptureFolders?
    @ObservationIgnored var started = false
    @ObservationIgnored var cancelRequested = false
    @ObservationIgnored var sessionTasks: [Task<Void, Never>] = []
    @ObservationIgnored var buildTask: Task<Void, Never>?
    @ObservationIgnored var observer = BackgroundBuildObserver()
    @ObservationIgnored var backgroundTask = UIBackgroundTaskIdentifier.invalid
    @ObservationIgnored var lastLoggedTenth = -1
    @ObservationIgnored var lastFraction = 0.0

    init(environment: AppEnvironment, root: URL = ObjectCapturePhotoCapture.standardDirectory()) {
        capture = environment.photoCapture
        library = environment.library
        log = environment.log
        self.root = root
    }

    var detailLevel: PhotoDetailLevel { capture.detailLevel }

    /// Whether the photographs are still on disk, so "Discard capture" makes sense.
    var hasCaptureOnDisk: Bool { folders != nil && !captureDiscarded }

    // MARK: - Starting

    /// Runs once when the screen appears.
    func start() {
        guard !started else { return }
        started = true
        log.info("photo", "Photo capture opened", ["detail": detailLevel.manifestValue])
        Task { await begin() }
    }

    /// Offers an unfinished capture first, if there is one; otherwise starts capturing.
    func begin() async {
        let root = root
        let leftovers = await Task.detached(priority: .userInitiated) { RawCaptureFiles.unfinished(in: root) }.value
        if let first = leftovers.first {
            unfinished = first
            log.info(
                "photo", "Unfinished capture found",
                ["images": String(first.images), "bytes": String(first.bytes), "count": String(leftovers.count)])
            return
        }
        await prepareAndCapture()
    }

    func prepareAndCapture() async {
        do {
            try await capture.prepare()
        } catch {
            fail(ObjectCapturePhotoCapture.translate(error))
            return
        }
        guard apply(.ready) else { return }
        startSession()
    }

    /// Builds the unfinished capture without capturing again (FR-4.3).
    func buildUnfinished() {
        guard let leftover = unfinished else { return }
        unfinished = nil
        folders = leftover.folders
        log.info("photo", "Unfinished capture resumed", ["images": String(leftover.images)])
        guard apply(.resumed(images: leftover.images)) else { return }
        startBuild()
    }

    /// Removes the unfinished capture, then looks for another or starts capturing.
    func discardUnfinished() {
        guard let leftover = unfinished else { return }
        unfinished = nil
        do {
            try RawCaptureFiles.discard(leftover.folders)
            log.info("photo", "Unfinished capture discarded", ["bytes": String(leftover.bytes)])
        } catch {
            log.error("photo", "Unfinished capture not discarded", ["reason": describe(error)])
        }
        Task { await begin() }
    }

    // MARK: - Guided capture

    func startSession() {
        let folders = RawCaptureFolders.new(in: root)
        self.folders = folders
        do {
            // Object Capture makes the Images and Checkpoint folders itself and insists
            // they are new, so only the parent is created here.
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            fail(PhotoCaptureError.from(error))
            return
        }
        let session = ObjectCaptureSession()
        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = folders.checkpoint
        tracker = PhotoSessionTracker()
        self.session = session
        // Listen first, start, then read the state once: the session can become ready
        // before the listener hears anything, and then "ready" would be missed (the
        // build 8 fault: only Cancel under the aiming brackets). A repeat is ignored.
        observe(session)
        session.start(imagesDirectory: folders.images, configuration: configuration)
        log.info("photo", "Capture started", ["capture": String(folders.id.prefix(8))])
        handle(session.state)
    }

    /// Follows the session's state, shot count, advice and scan-pass dial. Each loop
    /// runs on the main thread, as this model does, so it can update the screen.
    func observe(_ session: ObjectCaptureSession) {
        sessionTasks.append(
            Task { [weak self] in
                for await state in session.stateUpdates {
                    self?.handle(state)
                }
            })
        sessionTasks.append(
            Task { [weak self] in
                for await shots in session.numberOfShotsTakenUpdates {
                    self?.shotsTaken(shots)
                }
            })
        sessionTasks.append(
            Task { [weak self] in
                for await feedback in session.feedbackUpdates {
                    self?.show(feedback)
                }
            })
        sessionTasks.append(
            Task { [weak self] in
                for await complete in session.userCompletedScanPassUpdates {
                    self?.scanPassComplete = complete
                    if complete { self?.log.info("photo", "Scan pass complete") }
                }
            })
    }

    func handle(_ state: ObjectCaptureSession.CaptureState) {
        let plain = PhotoSessionState(state)
        guard let plain else {
            log.warning("photo", "Unrecognised capture state")
            return
        }
        let before = tracker.lastState
        let action = tracker.observe(plain)
        if before != plain {
            log.info("photo", "Session state", ["state": plain.logName, "step": String(describing: tracker.step)])
        }
        switch plain {
        case .detecting:
            detectHint = nil
        case .capturing where before != .capturing:
            log.info("photo", "Taking photos")
        default:
            break
        }
        perform(action, for: state)
    }

    /// Carries out what the tracker asked for after a state change.
    func perform(_ action: PhotoSessionAction?, for state: ObjectCaptureSession.CaptureState) {
        switch action {
        case .startDetecting:
            // Puts a box round the object in the middle of the picture. Fails (returns
            // false) when no flat surface is found under it.
            if session?.startDetecting() == false {
                detectHint = "Put the object on a flat surface and point at it, or start without the box."
                log.info("photo", "Object not found yet")
            } else {
                detectHint = nil
                log.info("photo", "Looking for the object")
            }
        case .captureFinishing:
            apply(.captureFinishing)
        case .captureCompleted:
            captureCompleted()
        case .captureFailed:
            if case .failed(let error) = state {
                log.error("photo", "Capture session failed", ["reason": describe(error)])
                captureFailed(error)
            }
        case nil:
            break
        }
    }

    /// Starts taking photographs: with the box (after detecting) or without it.
    func startCapturing() {
        log.info("photo", "Capture button tapped", ["withBox": String(step == .objectFound)])
        session?.startCapturing()
    }

    /// Tries to find the object again after moving the phone.
    func retryDetecting() {
        if session?.startDetecting() == true {
            detectHint = nil
        }
    }

    /// Another trip round at a different height, keeping the same box.
    func anotherPass() {
        session?.beginNewScanPass()
        scanPassComplete = false
        log.info("photo", "Another scan pass started")
    }

    func finishCapture() {
        if case .capturing(let shots) = flow.phase {
            log.info("photo", "Finish tapped", ["shots": String(shots)])
        }
        session?.finish()
    }

    func captureCompleted() {
        endSession()
        guard let folders else { return }
        let images = RawCaptureFiles.imageCount(in: folders)
        log.info("photo", "Capture completed", ["images": String(images)])
        guard apply(.captureCompleted(images: images)) else { return }
        if flow.canBuild {
            startBuild()
        } else {
            discardFolders(reason: "too few photos")
        }
    }

    func captureFailed(_ error: any Error) {
        endSession()
        if cancelRequested {
            discardFolders(reason: "cancelled")
            return
        }
        fail(ObjectCapturePhotoCapture.translate(error))
        discardFolders(reason: "capture failed")
    }

    /// The count can still tick while the last photos are saved; only counts during
    /// capturing matter.
    func shotsTaken(_ shots: Int) {
        guard case .capturing = flow.phase else { return }
        apply(.shotsTaken(shots))
    }

    func show(_ feedback: Set<ObjectCaptureSession.Feedback>) {
        let text = PhotoCaptureAdvice.advice(for: feedback)
        if text != feedbackText, let text {
            log.info("photo", "Capture advice", ["advice": text])
        }
        feedbackText = text
    }

    func endSession() {
        for task in sessionTasks {
            task.cancel()
        }
        sessionTasks = []
        session = nil
    }

    // MARK: - Helpers

    /// Applies an event to the flow, logging any the flow refuses (business rule PC-1).
    @discardableResult
    func apply(_ event: PhotoCaptureEvent) -> Bool {
        let accepted = flow.apply(event)
        if !accepted {
            log.warning("photo", "Photo event ignored", ["event": String(describing: event), "phase": phaseName])
        }
        return accepted
    }

    func fail(_ error: PhotoCaptureError) {
        log.error("photo", "Photo capture failed", ["error": error.logName, "reason": describe(error)])
        apply(.failed(error))
    }

    func describe(_ error: any Error) -> String {
        ObjectCapturePhotoCapture.describe(error)
    }

    /// The phase's name without its details, for the log.
    var phaseName: String {
        String(String(describing: flow.phase).prefix { $0 != "(" })
    }
}

/// The platform's capture advice in plain words.
enum PhotoCaptureAdvice {
    /// The most useful single piece of the platform's advice, in plain words.
    static func advice(for feedback: Set<ObjectCaptureSession.Feedback>) -> String? {
        let ordered: [(ObjectCaptureSession.Feedback, String)] = [
            (.environmentTooDark, "Too dark: add light"),
            (.environmentLowLight, "Low light: add light if you can"),
            (.movingTooFast, "Move slower"),
            (.objectTooClose, "Move back a little"),
            (.objectTooFar, "Move closer"),
            (.outOfFieldOfView, "Keep the object in view"),
            (.objectNotDetected, "Point at the object"),
            (.overCapturing, "Enough photos here: move round"),
            (.objectNotFlippable, "This object should not be turned over"),
        ]
        return ordered.first { feedback.contains($0.0) }?.1
    }
}

extension PhotoSessionState {
    /// The platform's state without its error, for Core's tracker; nil for a state this
    /// build does not know.
    init?(_ state: ObjectCaptureSession.CaptureState) {
        switch state {
        case .initializing: self = .initialising
        case .ready: self = .ready
        case .detecting: self = .detecting
        case .capturing: self = .capturing
        case .finishing: self = .finishing
        case .completed: self = .completed
        case .failed: self = .failed
        @unknown default: return nil
        }
    }
}
