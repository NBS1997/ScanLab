import Foundation

/// Reads the distance at the centre of a depth frame (FR-2.2).
///
/// A single pixel is noisy, so this takes a small square of pixels around the centre
/// and returns their median: the middle value once sorted. The median ignores a few
/// stray readings that an average would be pulled about by.
public enum CentreSampler {
    /// The default square is 5 × 5 pixels, about 2% of the frame's width.
    public static let defaultWindow = 5

    /// - Parameters:
    ///   - window: the side of the square, in pixels; clamped to fit the frame.
    ///   - minimumConfidence: pixels less confident than this are ignored. Nil uses
    ///     every pixel. Ignored when the frame has no confidence values.
    /// - Returns: the median distance in metres, or nil when no pixel has a reading.
    public static func distance(
        in frame: DepthFrame, window: Int = defaultWindow, minimumConfidence: ConfidenceLevel? = .medium
    ) -> Float? {
        let side = min(max(window, 1), frame.width, frame.height)
        let firstColumn = (frame.width - side) / 2
        let firstRow = (frame.height - side) / 2
        var readings: [Float] = []
        readings.reserveCapacity(side * side)
        for row in firstRow..<(firstRow + side) {
            for column in firstColumn..<(firstColumn + side) {
                guard let metres = frame.depth(column: column, row: row), DepthFrame.isValid(metres) else {
                    continue
                }
                if let minimum = minimumConfidence, frame.hasConfidence {
                    guard let level = frame.confidenceLevel(column: column, row: row), level >= minimum else {
                        continue
                    }
                }
                readings.append(metres)
            }
        }
        return median(of: readings)
    }

    /// The middle value; for an even count, halfway between the two middle values.
    static func median(of values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[middle]
        }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
}
