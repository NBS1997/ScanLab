import Foundation

/// Paints the depth and confidence layers as pictures, one pixel per sensor reading.
/// The pictures are in the sensor's orientation; the app turns them to match the way
/// the phone is held (`RGBAImage.rotated`).
public enum OverlayRenderer {
    public static func depthImage(for frame: DepthFrame, using map: DepthColourMap = .standard) -> RGBAImage {
        var image = RGBAImage(width: frame.width, height: frame.height)
        for row in 0..<frame.height {
            for column in 0..<frame.width {
                let metres = frame.depths[row * frame.width + column]
                image.setPixel(column: column, row: row, to: map.colour(forMetres: metres))
            }
        }
        return image
    }

    /// Nil when the frame carries no confidence values.
    public static func confidenceImage(
        for frame: DepthFrame, using map: ConfidenceColourMap = .standard
    ) -> RGBAImage? {
        guard frame.hasConfidence else { return nil }
        var image = RGBAImage(width: frame.width, height: frame.height)
        for row in 0..<frame.height {
            for column in 0..<frame.width {
                let value = frame.confidence[row * frame.width + column]
                image.setPixel(column: column, row: row, to: map.colour(forRawValue: value))
            }
        }
        return image
    }
}
