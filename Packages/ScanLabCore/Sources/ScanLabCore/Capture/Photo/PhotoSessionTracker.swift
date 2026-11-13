import Foundation

/// The states of the platform's guided photo capture (Object Capture), without the
/// platform's own types, so the rules below can be tested (ADR-003).
public enum PhotoSessionState: Equatable, Sendable {
    case initialising
    /// Ready to look for the object: the moment to call `startDetecting`.
    case ready
    /// A box is round the object, waiting for Start capture.
    case detecting
    case capturing
    case finishing
    case completed
    case failed

    public var logName: String {
        switch self {
        case .initialising: "initialising"
        case .ready: "ready"
        case .detecting: "detecting"
        case .capturing: "capturing"
        case .finishing: "finishing"
        case .completed: "completed"
        case .failed: "failed"
        }
    }
}

/// Where the guided capture has got to, for the buttons and words under the camera.
public enum PhotoGuidedStep: Equatable, Sendable {
    case starting
    /// Looking for the object; `startDetecting` is tried automatically.
    case lookingForObject
    /// A box is round the object; the owner adjusts it, then starts.
    case objectFound
    case capturing
    case finishing
}

/// What the screen must do after a state change.
public enum PhotoSessionAction: Equatable, Sendable {
    case startDetecting
    case captureFinishing
    case captureCompleted
    case captureFailed
}

/// Follows the platform's capture state and says what to do about each change.
///
/// **The fault this fixes (build 8):** the platform can reach "ready" before the app
/// starts listening for state changes. The listener then never hears "ready", the
/// object is never looked for, and the screen stays on "starting" with only Cancel,
/// under the platform's aiming brackets. The screen now reads the current state as
/// soon as it starts listening, as well as every change after. Hearing the same state
/// twice (once read, once from the listener) must not act twice, so a repeat is
/// ignored here.
public struct PhotoSessionTracker: Equatable, Sendable {
    public private(set) var step = PhotoGuidedStep.starting
    public private(set) var lastState: PhotoSessionState?

    public init() {}

    /// Takes a state, read or heard. Returns what to do, or nil for a repeat or a state
    /// that only changes the step.
    public mutating func observe(_ state: PhotoSessionState) -> PhotoSessionAction? {
        guard state != lastState else { return nil }
        lastState = state
        switch state {
        case .initialising:
            step = .starting
            return nil
        case .ready:
            step = .lookingForObject
            return .startDetecting
        case .detecting:
            step = .objectFound
            return nil
        case .capturing:
            step = .capturing
            return nil
        case .finishing:
            step = .finishing
            return .captureFinishing
        case .completed:
            return .captureCompleted
        case .failed:
            return .captureFailed
        }
    }

    /// The photo count is only shown once photos are being taken, so "0 photos" never
    /// looks like a capture that is running but not working.
    public var showsPhotoCount: Bool {
        step == .capturing || step == .finishing
    }

    /// What to do next, in plain words.
    public var instruction: String {
        switch step {
        case .starting:
            "Starting the camera…"
        case .lookingForObject:
            "Point at the part on a flat surface. Tap Find object, or Start without box."
        case .objectFound:
            "Box found. Adjust it if needed, then tap Start capture."
        case .capturing:
            "Walk slowly round the part. Photos are taken on their own."
        case .finishing:
            "Saving the last photos…"
        }
    }
}
