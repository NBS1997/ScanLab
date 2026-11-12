import CoreVideo
import Foundation
import ScanLabCore
import Vision

/// Outlines the object under a tap with Vision's subject-lifting model (SB-2, ADR-030).
///
/// `VNGenerateForegroundInstanceMaskRequest` is the same on-phone model the Photos app
/// uses to lift a subject out of a picture. It labels every pixel with a number: 0 for
/// background, 1, 2, 3… for each separate object it found. The object under the tap is
/// the one whose number is at the tapped spot.
///
/// The outline is sampled onto a 256 × 192 grid, the depth picture's own size, because
/// that is as fine as it can be used.
enum SubjectMasker {
    static let gridWidth = 256
    static let gridHeight = 192

    /// The outline of the object at `point` (fractions of the picture, across then
    /// down), or nil when Vision fails or the tap is on background.
    static func mask(in picture: CVPixelBuffer, at point: CGPoint, log: any Logging) -> SubjectMask? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        // `.up`: the outline comes back in the picture's own sideways orientation, which
        // is also the depth picture's.
        let handler = VNImageRequestHandler(cvPixelBuffer: picture, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            log.warning("capture", "Subject outline failed", ["reason": error.localizedDescription])
            return nil
        }
        guard let observation = request.results?.first else {
            log.info("capture", "Subject outline empty", ["reason": "Vision found no objects"])
            return nil
        }
        let mask = outline(in: observation.instanceMask, at: point)
        if mask == nil {
            log.info("capture", "Subject outline empty", ["reason": "tap is on background"])
        }
        return mask
    }

    /// Reads the object numbers and keeps the pixels that share the tapped one.
    static func outline(in labels: CVPixelBuffer, at point: CGPoint) -> SubjectMask? {
        guard CVPixelBufferGetPixelFormatType(labels) == kCVPixelFormatType_OneComponent8,
            CVPixelBufferLockBaseAddress(labels, .readOnly) == kCVReturnSuccess
        else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(labels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(labels) else { return nil }
        let width = CVPixelBufferGetWidth(labels)
        let height = CVPixelBufferGetHeight(labels)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(labels)
        func label(across: Double, down: Double) -> UInt8 {
            let column = min(max(Int(across * Double(width)), 0), width - 1)
            let row = min(max(Int(down * Double(height)), 0), height - 1)
            return base.load(fromByteOffset: row * bytesPerRow + column, as: UInt8.self)
        }
        guard point.x >= 0, point.x < 1, point.y >= 0, point.y < 1 else { return nil }
        let tapped = label(across: Double(point.x), down: Double(point.y))
        guard tapped != 0 else { return nil }
        var inside = [Bool](repeating: false, count: gridWidth * gridHeight)
        for row in 0..<gridHeight {
            for column in 0..<gridWidth {
                let across = (Double(column) + 0.5) / Double(gridWidth)
                let down = (Double(row) + 0.5) / Double(gridHeight)
                inside[row * gridWidth + column] = label(across: across, down: down) == tapped
            }
        }
        return SubjectMask(width: gridWidth, height: gridHeight, inside: inside)
    }
}
