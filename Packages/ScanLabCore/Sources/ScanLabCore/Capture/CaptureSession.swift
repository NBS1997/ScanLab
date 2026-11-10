import Foundation

/// Why a capture did not produce a scan. Each case says what happened and what to do
/// next, so the Capture screen can show it in place (mockups decision Q3-A).
public enum CaptureError: Error, Equatable, Sendable {
    /// The owner has not allowed ScanLab to use the camera.
    case permissionDenied
    /// This phone cannot do the kind of capture asked for.
    case sensorUnavailable(String)
    /// The camera session stopped with an error part-way through.
    case sessionFailed(String)
    /// Finish was tapped but no surface had been reconstructed yet.
    case nothingCaptured
    /// The phone does not have room for the scan. Nothing was saved (NFR-9).
    case noSpace
    /// The model was built but could not be saved.
    case saveFailed(String)
    /// The model could not be built from what was captured.
    case buildFailed(String)

    /// Turns any error from the capture or the library into a capture error, so the
    /// screen only ever has one kind of message to show.
    public init(wrapping error: any Error) {
        switch error {
        case let capture as CaptureError:
            self = capture
        case StoreError.noSpace:
            self = .noSpace
        case let store as StoreError:
            self = .saveFailed(store.errorDescription ?? String(describing: store))
        default:
            self = .buildFailed(error.localizedDescription)
        }
    }
}

extension CaptureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "ScanLab is not allowed to use the camera. To allow it, open Settings, choose ScanLab "
                + "and turn on Camera."
        case .sensorUnavailable(let reason):
            return reason
        case .sessionFailed(let reason):
            return "The camera stopped: \(reason). Nothing was saved. Try again."
        case .nothingCaptured:
            return "Nothing was captured, so nothing was saved. Point the phone at the subject from about "
                + "half a metre away and move slowly until the mesh appears over it."
        case .noSpace:
            return "There is not enough free space to save the scan, so nothing was saved. "
                + "Free up some space, then try again."
        case .saveFailed(let reason):
            return reason
        case .buildFailed(let reason):
            return "The model could not be built: \(reason). Nothing was saved. Try again."
        }
    }
}

/// Where a capture is up to. The Capture screen shows one state at a time
/// (interaction-spec.md, states table).
public enum CapturePhase: Equatable, Sendable {
    /// Nothing started yet.
    case idle
    /// The camera and tracking are starting.
    case preparing
    /// The owner is moving the phone over the subject.
    case capturing
    /// Finish was tapped: the model is being built and saved.
    case finishing
    /// The scan is in the library under this identity.
    case saved(UUID)
    /// The capture stopped without a scan.
    case failed(CaptureError)
    /// The owner closed the capture; nothing was saved.
    case cancelled

    /// True once the capture is over, one way or another.
    public var isOver: Bool {
        switch self {
        case .saved, .failed, .cancelled: true
        case .idle, .preparing, .capturing, .finishing: false
        }
    }

    /// A short name for the diagnostics log.
    public var logName: String {
        switch self {
        case .idle: "idle"
        case .preparing: "preparing"
        case .capturing: "capturing"
        case .finishing: "finishing"
        case .saved: "saved"
        case .failed: "failed"
        case .cancelled: "cancelled"
        }
    }
}

/// Something that happens to a capture.
public enum CaptureSessionEvent: Equatable, Sendable {
    /// The owner chose a method (or tapped Try again after a failure).
    case start
    /// The sensor delivered its first picture: capturing has begun.
    case sensorReady
    /// The owner tapped Finish.
    case finish
    /// The scan was saved to the library.
    case saved(UUID)
    /// Something went wrong.
    case fail(CaptureError)
    /// The owner closed the capture.
    case cancel

    var logName: String {
        switch self {
        case .start: "start"
        case .sensorReady: "sensorReady"
        case .finish: "finish"
        case .saved: "saved"
        case .fail: "fail"
        case .cancel: "cancel"
        }
    }
}

/// An event that is not allowed in the current phase, such as Finish before the camera
/// has started. The screen disables the matching buttons, so this signals a bug.
public struct CaptureTransitionError: Error, Equatable, Sendable {
    public let phase: CapturePhase
    public let event: CaptureSessionEvent
}

/// The rules for moving a capture from one phase to the next (CaptureSession in
/// components.md). It holds no camera or file code, only the allowed steps:
///
/// ```
/// idle ──start──▶ preparing ──sensorReady──▶ capturing ──finish──▶ finishing ──saved──▶ saved
///                     │                          │                     │
///                     └────────fail──────────────┴─────────fail────────┴──▶ failed ──start──▶ preparing
/// idle, preparing, capturing ──cancel──▶ cancelled
/// ```
///
/// Cancel is not allowed while finishing: the save is already under way and stopping
/// it half-way would gain nothing, because the library writes a scan all at once.
public struct CaptureSession: Equatable, Sendable {
    public private(set) var phase: CapturePhase

    public init(phase: CapturePhase = .idle) {
        self.phase = phase
    }

    /// Whether `event` is allowed now.
    public func allows(_ event: CaptureSessionEvent) -> Bool {
        Self.next(after: phase, on: event) != nil
    }

    /// Moves to the next phase, or throws without changing anything when the event is
    /// not allowed now.
    @discardableResult
    public mutating func apply(_ event: CaptureSessionEvent) throws -> CapturePhase {
        guard let next = Self.next(after: phase, on: event) else {
            throw CaptureTransitionError(phase: phase, event: event)
        }
        phase = next
        return next
    }

    /// The whole table of allowed steps in one place.
    static func next(after phase: CapturePhase, on event: CaptureSessionEvent) -> CapturePhase? {
        switch (phase, event) {
        case (.idle, .start), (.failed, .start):
            return .preparing
        case (.preparing, .sensorReady):
            return .capturing
        case (.capturing, .finish):
            return .finishing
        case (.finishing, .saved(let id)):
            return .saved(id)
        case (.preparing, .fail(let error)), (.capturing, .fail(let error)), (.finishing, .fail(let error)):
            return .failed(error)
        case (.idle, .cancel), (.preparing, .cancel), (.capturing, .cancel):
            return .cancelled
        default:
            return nil
        }
    }
}
