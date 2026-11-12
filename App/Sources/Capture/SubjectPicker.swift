import ARKit
import Foundation
import ScanLabCore
import UIKit

/// Turns a tap on the camera view into a subject box (SB-2 to SB-5, ADR-030).
///
/// A tap is remembered until the next camera frame arrives. That frame's depth picture,
/// lens numbers, camera position and colour picture are taken, and the slow part runs on
/// a background queue: Vision outlines the object under the tap, then Core's
/// `SubjectFinder` fits the box. The caller simply awaits the result.
///
/// `@unchecked Sendable` is safe because the only changing value, `pending`, is guarded
/// by `lock`; everything else is set once.
final class SubjectPicker: @unchecked Sendable {
    typealias Outcome = Result<SubjectBox, SubjectPickError>

    /// One tap waiting for a frame. The tap is in fractions of the camera view (0 to 1).
    private struct Request: Sendable {
        let viewPoint: CGPoint
        let viewport: CGSize
        let orientation: UIInterfaceOrientation
        let continuation: CheckedContinuation<Outcome, Never>
    }

    /// Lets a camera picture cross to the Vision queue. A pixel buffer is a Core
    /// Foundation object Swift cannot check; this one is only read, never changed.
    private struct PictureBuffer: @unchecked Sendable {
        let buffer: CVPixelBuffer
    }

    private let log: any Logging
    private let lock = NSLock()
    private var pending: Request?
    private let visionQueue = DispatchQueue(label: "com.nbs1997.scanlab.subject", qos: .userInitiated)

    init(log: any Logging) {
        self.log = log
    }

    /// Waits for the next frame and finds the subject under `viewPoint`. A newer tap
    /// replaces an older one still waiting, which then gets `.notReady`.
    func pick(viewPoint: CGPoint, viewport: CGSize, orientation: UIInterfaceOrientation) async -> Outcome {
        await withCheckedContinuation { continuation in
            let request = Request(
                viewPoint: viewPoint, viewport: viewport, orientation: orientation, continuation: continuation)
            let replaced = lock.withLock {
                let old = pending
                pending = request
                return old
            }
            replaced?.continuation.resume(returning: .failure(.notReady))
        }
    }

    /// Answers a waiting tap with `.notReady`, when the capture stops.
    func cancel() {
        let waiting = lock.withLock {
            let old = pending
            pending = nil
            return old
        }
        waiting?.continuation.resume(returning: .failure(.notReady))
    }

    /// Called with every camera frame (on the sweep queue). Does nothing unless a tap is
    /// waiting; then copies what it needs from the frame at once, so the frame is not kept.
    func offer(_ frame: ARFrame) {
        let request = lock.withLock {
            let waiting = pending
            pending = nil
            return waiting
        }
        guard let request else { return }
        guard let picture = SweepReceiver.fusionFrame(from: frame) else {
            log.warning("capture", "Subject not found", ["reason": "no depth picture in the frame"])
            request.continuation.resume(returning: .failure(.noDepthThere))
            return
        }
        // The camera view shows a cropped, rotated version of the camera picture. The
        // platform's "display transform" maps picture positions to view positions;
        // turned round ("inverted") it maps the tap back into the picture.
        let toPicture = frame.displayTransform(for: request.orientation, viewportSize: request.viewport).inverted()
        let pictureTap = request.viewPoint.applying(toPicture)
        let colour = PictureBuffer(buffer: frame.capturedImage)
        visionQueue.async { [self] in
            let start = ProcessInfo.processInfo.systemUptime
            let mask = SubjectMasker.mask(in: colour.buffer, at: pictureTap, log: log)
            let result = SubjectFinder.find(
                in: picture, tappedColumn: Double(pictureTap.x) * Double(picture.depth.width) - 0.5,
                tappedRow: Double(pictureTap.y) * Double(picture.depth.height) - 0.5, mask: mask)
            let milliseconds = String(format: "%.0f", (ProcessInfo.processInfo.systemUptime - start) * 1_000)
            switch result {
            case .success(let box):
                var details = box.logDetails
                details["ms"] = milliseconds
                log.info("capture", "Subject found", details)
            case .failure(let error):
                log.info("capture", "Subject not found", ["reason": error.logName, "ms": milliseconds])
            }
            request.continuation.resume(returning: result)
        }
    }
}
