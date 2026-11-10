import CoreGraphics
import Foundation
import ScanLabCore
import UIKit

/// The app's view of the live sensor: Core's `SensorFeeding` port, plus a view that
/// shows the live camera picture. The picture stays on the app side because it is a
/// camera-framework object that Core must not know about (ADR-003).
protocol LiveCameraFeeding: SensorFeeding {
    /// A view that draws the live camera picture, filling its bounds.
    @MainActor func makeCameraView() -> UIView
}

/// A stand-in for SwiftUI previews: no camera, one made-up depth frame.
final class PreviewSensorFeed: LiveCameraFeeding {
    func start() -> SensorStreams {
        let (frames, frameContinuation) = AsyncStream.makeStream(of: SensorFrame.self)
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        statusContinuation.yield(.running)
        statusContinuation.finish()
        // A slope from 0.3 m on the left to 4.8 m on the right.
        let width = 256
        let height = 192
        var depths: [Float] = []
        depths.reserveCapacity(width * height)
        for _ in 0..<height {
            for column in 0..<width {
                depths.append(0.3 + 4.5 * Float(column) / Float(width - 1))
            }
        }
        let confidence = [UInt8](repeating: 2, count: width * height)
        let depth = DepthFrame(width: width, height: height, depths: depths, confidence: confidence)
        frameContinuation.yield(SensorFrame(timestamp: 0, depth: depth))
        frameContinuation.finish()
        return SensorStreams(frames: frames, statuses: statuses)
    }

    func stop() {}

    @MainActor func makeCameraView() -> UIView {
        let view = UIView()
        view.backgroundColor = .darkGray
        return view
    }
}

extension RGBAImage {
    /// The picture as a system image for SwiftUI to draw. The bytes are copied into
    /// the image, so later changes to this value do not affect it.
    func makeCGImage() -> CGImage? {
        guard width > 0, height > 0, let provider = CGDataProvider(data: Data(bytes) as CFData) else {
            return nil
        }
        // Four bytes per pixel in the order red, green, blue, opacity ("alpha last"),
        // with colour values not pre-multiplied by opacity.
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil,
            shouldInterpolate: true, intent: .defaultIntent)
    }
}
