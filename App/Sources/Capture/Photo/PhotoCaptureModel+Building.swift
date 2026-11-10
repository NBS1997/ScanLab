import Foundation
import ScanLabCore
import SwiftUI
import UIKit

// Building, saving, the raw-capture question, cancelling and the background
// observation for the photo capture screen. Split from PhotoCaptureModel.swift only to
// keep each file a readable length; it is the same class.

extension PhotoCaptureModel {
    // MARK: - Building

    /// Builds (or builds again) from the photographs on disk.
    func startBuild() {
        guard let folders, apply(.buildStarted(time: Date())) else { return }
        lastLoggedTenth = -1
        let stream = capture.build(folders)
        buildTask = Task { [weak self] in
            do {
                for try await event in stream {
                    await self?.handle(event)
                }
            } catch {
                self?.buildFailed(error)
            }
        }
    }

    func handle(_ event: PhotoBuildEvent) async {
        switch event {
        case .photosRead:
            log.info("photo", "Photos read; building")
        case .photoSkipped:
            // The adapter logs the total once; one entry per photo would flood the log.
            break
        case .progress(let update):
            apply(.buildProgressed(update, time: Date()))
            if let fraction = flow.buildFraction {
                lastFraction = fraction
                logProgress(fraction, stage: update.stage)
            }
        case .built(let result):
            guard apply(.modelBuilt) else { return }
            lastFraction = 1
            observer.buildEnded(.built)
            await save(result)
        }
    }

    /// One log entry per tenth of the way, so the log shows the pace of a build without
    /// an entry every second.
    func logProgress(_ fraction: Double, stage: BuildStage?) {
        let tenth = Int(fraction * 10)
        guard tenth > lastLoggedTenth else { return }
        lastLoggedTenth = tenth
        var details = ["percent": PhotoBuildText.percent(fraction), "stage": stage?.rawValue ?? "none"]
        details["background"] = String(observer.isAway)
        log.info("photo", "Build progress", details)
    }

    func buildFailed(_ error: any Error) {
        let failure = ObjectCapturePhotoCapture.translate(error)
        if failure == .cancelled {
            // Cancelled by the owner (already shown), or by the screen closing.
            observer.buildEnded(.cancelled)
            log.info("photo", "Build cancelled")
            apply(.cancelled)
        } else {
            observer.buildEnded(.failed)
            fail(failure)
        }
        endBackgroundTime()
    }

    // MARK: - Saving and the raw capture

    /// Reads the built model into a Core mesh (z-up, metres), saves it, tidies the
    /// capture folder down to what keeping needs, and asks keep or discard (FR-6.6).
    func save(_ result: PhotoBuildResult) async {
        endBackgroundTime()
        guard let folders else { return }
        let detail = detailLevel
        let modelFile = result.modelFile
        do {
            let mesh = try await Task.detached(priority: .userInitiated) {
                try PhotoModelImport.mesh(from: modelFile)
            }.value
            if let warning = PhotoModelImport.sizeWarning(for: mesh) {
                log.warning("photo", "Model size unexpected", ["reason": warning])
            }
            let scan = try await library.add(mesh: mesh, method: .photos, detail: detail.manifestValue)
            log.info(
                "photo", "Photo scan saved",
                [
                    "scan": String(scan.id.uuidString.prefix(8)), "faces": String(mesh.faceCount),
                    "size": scan.size.map(Units.formatDimensions) ?? "none", "route": result.route,
                    "positions": String(result.cameraPositions),
                ])
            let (images, bytes) = await Task.detached(priority: .userInitiated) {
                Self.tidyForKeeping(folders, detail: detail)
            }.value
            apply(.saved(KeepOffer(scanID: scan.id, scanName: scan.name, images: images, rawBytes: bytes)))
            if case .done = flow.phase {
                discardFolders(reason: "nothing to keep")
            }
        } catch {
            fail(PhotoCaptureError.from(error))
        }
    }

    /// Removes the working data and returns the photo count and the bytes left. A
    /// failure to tidy is not fatal: the size is then the whole folder.
    nonisolated static func tidyForKeeping(
        _ folders: RawCaptureFolders, detail: PhotoDetailLevel
    ) -> (Int, Int64) {
        let images = RawCaptureFiles.imageCount(in: folders)
        do {
            return (images, try RawCaptureFiles.prepareForKeeping(folders, detail: detail))
        } catch {
            return (images, RawCaptureFiles.bytes(in: folders.root))
        }
    }

    /// Moves the photographs and camera positions into the scan's folder.
    func keepRawCapture() async {
        guard case .askingToKeep(let offer) = flow.phase, let folders else { return }
        do {
            try await library.keepRawCapture(offer.scanID, from: folders.root)
            captureDiscarded = true
            apply(.rawCaptureDecided(keep: true))
        } catch {
            fail(PhotoCaptureError.from(error))
        }
    }

    func discardRawCapture() {
        guard case .askingToKeep = flow.phase else { return }
        discardFolders(reason: "owner chose discard")
        apply(.rawCaptureDecided(keep: false))
    }

    /// Removes the capture folder from a failed or cancelled capture.
    func discardCapture() {
        discardFolders(reason: "owner chose discard")
    }

    func discardFolders(reason: String) {
        guard let folders, !captureDiscarded else { return }
        let bytes = RawCaptureFiles.bytes(in: folders.root)
        do {
            try RawCaptureFiles.discard(folders)
            captureDiscarded = true
            log.info("photo", "Capture discarded", ["reason": reason, "bytes": String(bytes)])
        } catch {
            log.error("photo", "Capture not discarded", ["reason": describe(error)])
        }
    }

    // MARK: - Cancelling and closing

    /// Cancel: stops the capture (its photographs are removed) or the build (its
    /// photographs are kept, so Build again works).
    func cancel() {
        guard flow.canCancel else { return }
        log.info("photo", "Cancel tapped", ["phase": phaseName])
        let building = flow.buildFraction != nil
        // From "ready to build" onwards the photographs are complete, so they are kept
        // for Build again; before that they are an unfinished capture and are removed.
        var keepPhotos = building
        if case .readyToBuild = flow.phase { keepPhotos = true }
        cancelRequested = !keepPhotos
        apply(.cancelled)
        if building {
            observer.buildEnded(.cancelled)
            buildTask?.cancel()
        } else if let session {
            // The session reports `.failed(cancelled)` once it stops; the folder is
            // removed then, so nothing is deleted while it is still writing.
            session.cancel()
        } else if !keepPhotos {
            discardFolders(reason: "cancelled")
        }
    }

    /// The screen is going away: stop everything still running. A build stopped here
    /// leaves its photographs on disk, and they are offered next time (FR-4.3).
    func stop() {
        log.info("photo", "Photo capture closed", ["phase": phaseName])
        buildTask?.cancel()
        buildTask = nil
        if let session {
            cancelRequested = true
            session.cancel()
        }
        endBackgroundTime()
    }

    // MARK: - Background (requirements Open Question 3)

    /// Notes the progress when the app leaves and comes back during a build, and logs
    /// what happened in between.
    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            guard let fraction = flow.buildFraction else { return }
            observer.appLeft(at: Date(), fraction: fraction)
            log.info("photo", "App left during build", ["percent": PhotoBuildText.percent(fraction)])
            beginBackgroundTime()
        case .active:
            let fraction = flow.buildFraction ?? lastFraction
            if let seen = observer.appReturned(at: Date(), fraction: fraction) {
                var details = seen.logDetails
                details["summary"] = seen.summary
                log.info("photo", "Background build observed", details)
                backgroundNote = seen.summary
            }
            endBackgroundTime()
        default:
            break
        }
    }

    /// Asks the system for the short extra running time every app may have after it
    /// leaves the screen (no entitlement or setting needed). Whether building uses it,
    /// and what happens when it runs out, is exactly what is being observed.
    func beginBackgroundTime() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Build model") { [weak self] in
            // The system calls this on the main thread just before the time runs out.
            MainActor.assumeIsolated {
                self?.backgroundTimeExpired()
            }
        }
    }

    func backgroundTimeExpired() {
        log.warning(
            "photo", "Background time used up",
            ["percent": PhotoBuildText.percent(flow.buildFraction ?? lastFraction)])
        endBackgroundTime()
    }

    func endBackgroundTime() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
