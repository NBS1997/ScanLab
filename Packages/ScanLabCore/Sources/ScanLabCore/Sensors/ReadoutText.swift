import Foundation

/// The words and numbers the live view shows and the screen reader speaks.
///
/// Distances follow the app's rule (FR-6.4): millimetres below 1 m, metres from 1 m.
/// Kept here, not in a shared units file, until the shared one exists on this branch.
public enum ReadoutText {
    /// Shown when there is no reading.
    public static let noReading = "—"

    /// "845 mm" or "1.02 m"; a dash when there is no reading.
    public static func distance(metres: Float?) -> String {
        guard let metres, DepthFrame.isValid(metres) else { return noReading }
        let millimetres = Int((metres * 1_000).rounded())
        if millimetres < 1_000 {
            return "\(millimetres) mm"
        }
        return String(format: "%.2f m", metres)
    }

    /// "845 millimetres" or "1.02 metres", for the screen reader.
    public static func spokenDistance(metres: Float?) -> String {
        guard let metres, DepthFrame.isValid(metres) else { return "No reading" }
        let millimetres = Int((metres * 1_000).rounded())
        if millimetres == 1 {
            return "1 millimetre"
        }
        if millimetres < 1_000 {
            return "\(millimetres) millimetres"
        }
        return String(format: "%.2f metres", metres)
    }

    /// "60 fps", or "— fps" when not yet measured.
    public static func frameRate(_ framesPerSecond: Double?) -> String {
        guard let framesPerSecond, framesPerSecond.isFinite else { return "\(noReading) fps" }
        return String(format: "%.0f fps", framesPerSecond)
    }

    /// "60 frames per second", for the screen reader.
    public static func spokenFrameRate(_ framesPerSecond: Double?) -> String {
        guard let framesPerSecond, framesPerSecond.isFinite else { return "Not measured yet" }
        return String(format: "%.0f frames per second", framesPerSecond)
    }

    /// A distance for the legend: "0.2 m", "5 m".
    public static func legendDistance(metres: Float) -> String {
        let tenths = (metres * 10).rounded() / 10
        if tenths == tenths.rounded() {
            return String(format: "%.0f m", tenths)
        }
        return String(format: "%.1f m", tenths)
    }
}
