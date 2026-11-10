import Foundation

/// Where a model build has got to.
public struct BuildProgress: Equatable, Sendable {
    /// From 0 to 1. Never goes backwards while one build runs (business rule PC-4).
    public var fraction: Double
    public var stage: BuildStage?
    public var secondsRemaining: Double?
    /// When the last progress report arrived, so the screen can say if it is overdue.
    public var updatedAt: Date

    public init(fraction: Double, stage: BuildStage? = nil, secondsRemaining: Double? = nil, updatedAt: Date) {
        self.fraction = fraction
        self.stage = stage
        self.secondsRemaining = secondsRemaining
        self.updatedAt = updatedAt
    }
}

/// The question asked once a photo scan is saved (FR-6.6): keep the raw capture, or
/// discard it to free the space?
public struct KeepOffer: Equatable, Sendable {
    public var scanID: UUID
    public var scanName: String
    /// How many photographs the raw capture holds.
    public var images: Int
    /// How much storage keeping it uses.
    public var rawBytes: Int64

    public init(scanID: UUID, scanName: String, images: Int, rawBytes: Int64) {
        self.scanID = scanID
        self.scanName = scanName
        self.images = images
        self.rawBytes = rawBytes
    }
}

/// How a photo capture ended well.
public struct PhotoCaptureOutcome: Equatable, Sendable {
    public var scanID: UUID
    public var scanName: String
    /// The size of the kept raw capture, or `nil` when it was discarded.
    public var keptRawBytes: Int64?

    public init(scanID: UUID, scanName: String, keptRawBytes: Int64?) {
        self.scanID = scanID
        self.scanName = scanName
        self.keptRawBytes = keptRawBytes
    }
}

/// Every state the photo capture screen can be in.
public enum PhotoCapturePhase: Equatable, Sendable {
    /// Checking the phone and the camera permission.
    case preparing
    /// The guided capture is running; `shots` photographs so far.
    case capturing(shots: Int)
    /// The owner tapped Finish; the platform is saving the last photographs.
    case finishingCapture
    /// Photographs are on disk and a model can be built from them.
    case readyToBuild(images: Int)
    case building(BuildProgress)
    /// The model is built and being read and saved to the library.
    case saving
    /// The scan is saved; asking whether to keep the raw capture.
    case askingToKeep(KeepOffer)
    case done(PhotoCaptureOutcome)
    /// Stopped by an error. When `canBuildAgain` is true the photographs are still on
    /// disk, so building can start again without capturing again (FR-4.3).
    case failed(PhotoCaptureError, canBuildAgain: Bool)
    /// Stopped by the owner, with the same meaning of `canBuildAgain`.
    case cancelled(canBuildAgain: Bool)
}

/// What can happen to a photo capture.
public enum PhotoCaptureEvent: Equatable, Sendable {
    /// The phone and camera are ready; capturing begins.
    case ready
    /// An unfinished capture from earlier, with `images` photographs, is picked up.
    case resumed(images: Int)
    case shotsTaken(Int)
    case captureFinishing
    case captureCompleted(images: Int)
    case buildStarted(time: Date)
    case buildProgressed(BuildUpdate, time: Date)
    case modelBuilt
    case saved(KeepOffer)
    case rawCaptureDecided(keep: Bool)
    case failed(PhotoCaptureError)
    case cancelled
}

/// The photo capture state machine (business rules PC-1 to PC-8): which event is
/// allowed in which state, and what comes next. It holds no platform code, so every
/// path through it is tested in the build.
///
/// `apply` returns `false` for an event that makes no sense in the current state (for
/// example progress arriving after the build was cancelled). The state is then left
/// alone, and the app writes the refusal to the log.
public struct PhotoCaptureFlow: Equatable, Sendable {
    /// Fewer photographs than this cannot make a model worth keeping (PC-2). Apple
    /// publishes no minimum; this is ScanLab's own floor, an assumption to revisit
    /// once real captures have been tried.
    public static let minimumImages = 10

    public private(set) var phase: PhotoCapturePhase = .preparing

    public init(phase: PhotoCapturePhase = .preparing) {
        self.phase = phase
    }

    /// Whether the screen should offer Cancel.
    public var canCancel: Bool {
        switch phase {
        case .preparing, .capturing, .finishingCapture, .readyToBuild, .building: true
        default: false
        }
    }

    /// Whether a build may start now: photographs are waiting, or an earlier build
    /// failed or was cancelled with the photographs kept.
    public var canBuild: Bool {
        switch phase {
        case .readyToBuild: true
        case .failed(_, let again), .cancelled(let again): again
        default: false
        }
    }

    /// Whether the capture has reached an end and the screen can close without asking.
    public var isFinished: Bool {
        switch phase {
        case .done, .failed, .cancelled: true
        default: false
        }
    }

    /// The build's progress fraction, or `nil` when not building.
    public var buildFraction: Double? {
        if case .building(let progress) = phase { return progress.fraction }
        return nil
    }

    @discardableResult
    public mutating func apply(_ event: PhotoCaptureEvent) -> Bool {
        guard let next = next(after: event) else { return false }
        phase = next
        return true
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func next(after event: PhotoCaptureEvent) -> PhotoCapturePhase? {
        switch (phase, event) {
        case (.preparing, .ready):
            return .capturing(shots: 0)
        case (.preparing, .resumed(let images)):
            return Self.afterCapture(images: images)
        case (.capturing, .shotsTaken(let shots)):
            return .capturing(shots: max(shots, 0))
        case (.capturing, .captureFinishing):
            return .finishingCapture
        case (.capturing, .captureCompleted(let images)), (.finishingCapture, .captureCompleted(let images)):
            return Self.afterCapture(images: images)
        case (_, .buildStarted(let date)) where canBuild:
            return .building(BuildProgress(fraction: 0, updatedAt: date))
        case (.building(let progress), .buildProgressed(let update, let date)):
            return .building(Self.advance(progress, with: update, at: date))
        case (.building, .modelBuilt):
            return .saving
        case (.saving, .saved(let offer)):
            // Nothing to keep (no photographs on disk): finish without asking (PC-6).
            guard offer.rawBytes > 0 && offer.images > 0 else {
                return .done(PhotoCaptureOutcome(scanID: offer.scanID, scanName: offer.scanName, keptRawBytes: nil))
            }
            return .askingToKeep(offer)
        case (.askingToKeep(let offer), .rawCaptureDecided(let keep)):
            let kept = keep ? offer.rawBytes : nil
            return .done(PhotoCaptureOutcome(scanID: offer.scanID, scanName: offer.scanName, keptRawBytes: kept))
        case (.askingToKeep, .failed(let error)):
            // The scan is saved; only keeping the raw capture failed. Building again
            // would make a second scan, so it is not offered.
            return .failed(error, canBuildAgain: false)
        case (_, .failed(let error)) where !isFinished:
            return .failed(error, canBuildAgain: photosOnDisk && Self.retryHelps(error))
        case (_, .cancelled) where canCancel:
            return .cancelled(canBuildAgain: photosOnDisk)
        default:
            return nil
        }
    }

    /// Photographs are complete on disk from `readyToBuild` onwards (PC-3).
    private var photosOnDisk: Bool {
        switch phase {
        case .readyToBuild, .building, .saving: true
        default: false
        }
    }

    private static func afterCapture(images: Int) -> PhotoCapturePhase {
        guard images >= minimumImages else {
            return .failed(.tooFewImages(taken: max(images, 0), minimum: minimumImages), canBuildAgain: false)
        }
        return .readyToBuild(images: images)
    }

    /// Building again cannot fix a phone that lacks the sensor or a refused camera.
    private static func retryHelps(_ error: PhotoCaptureError) -> Bool {
        switch error {
        case .unsupportedDevice, .cameraDenied, .tooFewImages: false
        default: true
        }
    }

    /// Progress is clamped to 0–1 and never goes backwards (PC-4): the platform can
    /// restart its count for a new stage, which would otherwise make the bar jump back.
    private static func advance(_ progress: BuildProgress, with update: BuildUpdate, at date: Date) -> BuildProgress {
        let fraction = update.fraction.isFinite ? min(max(update.fraction, 0), 1) : progress.fraction
        return BuildProgress(
            fraction: max(progress.fraction, fraction),
            stage: update.stage ?? progress.stage,
            secondsRemaining: update.secondsRemaining,
            updatedAt: date)
    }
}
