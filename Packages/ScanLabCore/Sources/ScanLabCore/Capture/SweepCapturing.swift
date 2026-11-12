import Foundation

/// Why the phone is unsure where it is, in words the owner can act on.
public enum TrackingLimit: Equatable, Sendable {
    /// Tracking is still starting up.
    case initialising
    /// The phone is moving too fast for tracking to follow.
    case movingTooFast
    /// The picture has too little detail (a plain wall, darkness, a covered camera).
    case tooLittleDetail
    /// Tracking was lost and is finding its place again.
    case relocalising
    /// A reason this build does not know about.
    case other
}

/// How well the phone knows where it is while sweeping. Surfaces are only added to
/// the model while tracking is normal, so a limited state is worth telling the owner.
public enum SweepTracking: Equatable, Sendable {
    case normal
    case limited(TrackingLimit)
    case notAvailable

    /// The short prompt shown over the camera, or nil when all is well. Guidance with
    /// haptics and tones arrives with unit U09; this is the plain text version.
    public var prompt: String? {
        switch self {
        case .normal:
            return nil
        case .notAvailable:
            return "Tracking lost. Point the phone back at the subject."
        case .limited(let limit):
            switch limit {
            case .initialising: return "Starting tracking. Move the phone slowly."
            case .movingTooFast: return "Slow down."
            case .tooLittleDetail: return "Too little detail in view. Point at the subject."
            case .relocalising: return "Finding your place again. Point back at where you were."
            case .other: return "Tracking limited. Move slowly."
            }
        }
    }

    /// A short name for the diagnostics log.
    public var logName: String {
        switch self {
        case .normal: return "normal"
        case .notAvailable: return "not available"
        case .limited(let limit):
            switch limit {
            case .initialising: return "limited: initialising"
            case .movingTooFast: return "limited: moving too fast"
            case .tooLittleDetail: return "limited: too little detail"
            case .relocalising: return "limited: relocalising"
            case .other: return "limited: other"
            }
        }
    }
}

/// How a sweep is going, sent to the Capture screen a few times a second.
public struct SweepProgress: Equatable, Sendable {
    /// How many pieces of surface the platform has built so far. It splits the world
    /// into blocks about a metre across, each with its own piece of mesh.
    public var anchorCount: Int
    /// Triangles across all pieces so far.
    public var faceCount: Int
    /// Seconds since capturing began.
    public var elapsed: TimeInterval
    public var tracking: SweepTracking
    /// Depth pictures fused into the detailed model so far (U14, DF-9).
    public var fusedFrames: Int
    /// True once fusion memory is full and new areas are no longer added (DF-6).
    public var fusionFull: Bool

    public init(
        anchorCount: Int = 0, faceCount: Int = 0, elapsed: TimeInterval = 0, tracking: SweepTracking = .normal,
        fusedFrames: Int = 0, fusionFull: Bool = false
    ) {
        self.anchorCount = anchorCount
        self.faceCount = faceCount
        self.elapsed = elapsed
        self.tracking = tracking
        self.fusedFrames = fusedFrames
        self.fusionFull = fusionFull
    }

    public static let zero = SweepProgress()

    /// The prompt shown over the camera, or nil. A tracking problem matters most, because
    /// nothing is added while tracking is limited; next comes full fusion memory (DF-6).
    public var prompt: String? {
        if let trackingPrompt = tracking.prompt {
            return trackingPrompt
        }
        return fusionFull ? Self.fusionFullPrompt : nil
    }

    public static let fusionFullPrompt = "Detail memory full. Finish now, or start again closer to the subject."
}

/// The two streams a running sweep produces. Progress arrives often and only the
/// newest matters; status changes are rare and every one matters.
public struct SweepStreams: Sendable {
    public let progress: AsyncStream<SweepProgress>
    /// Uses the live sensor's statuses: starting, running, interrupted, permission
    /// denied, unsupported, failed and stopped.
    public let statuses: AsyncStream<SensorStatus>

    public init(progress: AsyncStream<SweepProgress>, statuses: AsyncStream<SensorStatus>) {
        self.progress = progress
        self.statuses = statuses
    }
}

/// The port for sweep capture (component-methods.md, ADR-005): the platform's scene
/// reconstruction builds a surface while the owner moves the phone; Finish hands it
/// over as one Core `Mesh`.
///
/// The mesh is in the platform's own axes: **y up**, in metres. The caller turns it to
/// z up with `Mesh.convertedFromYUp()` before saving, so every saved scan is z up.
///
/// Like the live sensor, the camera is shared: only one screen may hold it at a time.
public protocol SweepCapturing: Sendable {
    /// Starts the camera and reconstruction. Starting again restarts from nothing and
    /// ends the streams from the earlier call.
    @MainActor func start() -> SweepStreams

    /// Stops the camera and returns everything reconstructed, merged into one mesh.
    /// An empty mesh means nothing was captured.
    @MainActor func finish() async throws -> Mesh

    /// Stops the camera and throws away what was captured. Safe to call at any time.
    @MainActor func cancel()
}
