import Foundation

/// One update from the live sensor: when it was taken and, when the sensor had one,
/// the depth picture. The camera picture itself stays in the app, which draws it
/// directly (see `LiveSensorFeed`), so Core never holds a camera image.
public struct SensorFrame: Equatable, Sendable {
    public let timestamp: TimeInterval
    public let depth: DepthFrame?

    public init(timestamp: TimeInterval, depth: DepthFrame?) {
        self.timestamp = timestamp
        self.depth = depth
    }
}

/// What the live sensor is doing, for the screen to show and the log to record.
public enum SensorStatus: Equatable, Sendable {
    case starting
    case running
    /// The system paused the camera, for example while another app is in front.
    case interrupted
    case stopped
    /// The owner has not allowed ScanLab to use the camera.
    case permissionDenied
    /// This phone cannot give the depth the live view needs.
    case unsupported(reason: String)
    case failed(reason: String)

    /// The text shown on screen, or nil when the picture speaks for itself.
    public var message: String? {
        switch self {
        case .starting:
            "Starting camera"
        case .running:
            nil
        case .interrupted:
            "The camera is paused. It resumes when ScanLab is back in front."
        case .stopped:
            "Camera stopped"
        case .permissionDenied:
            "ScanLab is not allowed to use the camera. To allow it, open Settings, choose ScanLab "
                + "and turn on Camera."
        case .unsupported(let reason):
            reason
        case .failed(let reason):
            "The camera could not start: \(reason)"
        }
    }

    /// True when the live picture cannot appear until the owner does something.
    public var blocksView: Bool {
        switch self {
        case .permissionDenied, .unsupported, .failed: true
        case .starting, .running, .interrupted, .stopped: false
        }
    }
}

/// The two streams a running sensor produces. Frames arrive many times a second and
/// only the newest matters; status changes are rare and every one matters, so they
/// travel separately and are never dropped in favour of a frame.
public struct SensorStreams: Sendable {
    public let frames: AsyncStream<SensorFrame>
    public let statuses: AsyncStream<SensorStatus>

    public init(frames: AsyncStream<SensorFrame>, statuses: AsyncStream<SensorStatus>) {
        self.frames = frames
        self.statuses = statuses
    }
}

/// The port for the live camera and depth sensor (component-methods.md).
///
/// The sensor is shared: only one screen may hold it at a time, and a screen stops it
/// when it disappears (component-dependency.md, "Shared Resources").
public protocol SensorFeeding: Sendable {
    /// Starts the sensor. Starting while already running restarts it and ends the
    /// streams returned by the earlier call.
    @MainActor func start() -> SensorStreams

    /// Stops the sensor and ends the current streams. Safe to call when not running.
    @MainActor func stop()
}
