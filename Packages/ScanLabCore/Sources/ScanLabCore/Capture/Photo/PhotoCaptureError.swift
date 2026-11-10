import Foundation

/// Why a photo capture or build could not go on. Each case says what happened and what
/// to do next, so the screen can show it in place (mockups decision Q3-A), and each
/// is written to the diagnostics log.
public enum PhotoCaptureError: Error, Equatable, Sendable {
    /// The phone lacks what Object Capture needs (the depth sensor, or the platform
    /// says no).
    case unsupportedDevice
    /// The owner has not allowed ScanLab to use the camera.
    case cameraDenied
    /// Too few photographs were taken to build a model.
    case tooFewImages(taken: Int, minimum: Int)
    /// The guided capture stopped with an error, for example the sensor failed.
    case captureFailed(String)
    /// The platform could not build a model from the photographs.
    case buildFailed(String)
    /// Building finished but produced no usable model.
    case noModel
    /// The phone's storage is full. Nothing half-written is kept (NFR-9).
    case noSpace
    /// A file in the capture folder could not be read, written or removed.
    case fileFailed(String)
    /// The owner cancelled.
    case cancelled
}

extension PhotoCaptureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "This phone cannot take photo scans: Object Capture needs a LiDAR scanner. Use Sweep instead."
        case .cameraDenied:
            return "ScanLab is not allowed to use the camera. Allow it in Settings › Privacy & Security › Camera, "
                + "then try again."
        case .tooFewImages(let taken, let minimum):
            return "Only \(taken) photographs were taken; at least \(minimum) are needed. "
                + "Capture again and go all the way round the object."
        case .captureFailed(let reason):
            return "The capture stopped: \(reason). Close this screen and capture again."
        case .buildFailed(let reason):
            return "The model could not be built: \(reason). The photographs are kept, so you can build again."
        case .noModel:
            return "Building finished but no model came out. Build again, or capture again with more photographs."
        case .noSpace:
            return "There is not enough free space on the phone. Free up some space, then try again."
        case .fileFailed(let reason):
            return "A capture file could not be handled: \(reason)."
        case .cancelled:
            return "Cancelled."
        }
    }

    /// A short word for the log, for example "noSpace".
    public var logName: String {
        switch self {
        case .unsupportedDevice: "unsupportedDevice"
        case .cameraDenied: "cameraDenied"
        case .tooFewImages: "tooFewImages"
        case .captureFailed: "captureFailed"
        case .buildFailed: "buildFailed"
        case .noModel: "noModel"
        case .noSpace: "noSpace"
        case .fileFailed: "fileFailed"
        case .cancelled: "cancelled"
        }
    }

    /// Turns any error met while handling capture files into a `PhotoCaptureError`,
    /// recognising "storage full" in its several forms.
    public static func from(_ error: any Error) -> PhotoCaptureError {
        if let photoError = error as? PhotoCaptureError { return photoError }
        if let storeError = error as? StoreError {
            if storeError == .noSpace { return .noSpace }
            return .fileFailed(storeError.errorDescription ?? String(describing: storeError))
        }
        switch MeshFiles.classify(error) {
        case .noSpace: return .noSpace
        case .writeFailed(let reason), .readFailed(let reason): return .fileFailed(reason)
        case let other: return .fileFailed(other.errorDescription ?? String(describing: other))
        }
    }
}
