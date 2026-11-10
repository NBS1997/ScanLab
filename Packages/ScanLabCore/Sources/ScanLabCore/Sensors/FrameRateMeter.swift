import Foundation

/// Measures how many frames per second are arriving, over the most recent second or
/// so (NFR-7).
///
/// It keeps the timestamps that fall inside the window, in order. The rate is the
/// number of gaps between them divided by the time they span, so it is right even
/// when the window is only partly full. After a pause longer than the window, the old
/// timestamps fall away and the rate is reported again once two new frames arrive.
/// A timestamp that arrives late is slotted into place; one older than the window is
/// ignored.
public struct FrameRateMeter: Sendable {
    public let window: TimeInterval
    /// Timestamps inside the window, oldest first.
    public private(set) var timestamps: [TimeInterval] = []

    /// - Parameter window: seconds of history to keep; at least 0.01.
    public init(window: TimeInterval = 1) {
        self.window = window.isFinite ? max(window, 0.01) : 1
    }

    public mutating func record(_ timestamp: TimeInterval) {
        guard timestamp.isFinite else { return }
        if let latest = timestamps.last, timestamp < latest - window { return }
        // Find the place that keeps the list in order; usually that is the end.
        var index = timestamps.count
        while index > 0, timestamps[index - 1] > timestamp {
            index -= 1
        }
        timestamps.insert(timestamp, at: index)
        if let latest = timestamps.last {
            let cutoff = latest - window
            timestamps.removeAll { $0 < cutoff }
        }
    }

    /// Frames per second, or nil until there are two frames spread over some time.
    public var framesPerSecond: Double? {
        guard timestamps.count >= 2, let first = timestamps.first, let last = timestamps.last else { return nil }
        let span = last - first
        guard span > 0 else { return nil }
        return Double(timestamps.count - 1) / span
    }

    public mutating func reset() {
        timestamps.removeAll()
    }
}
