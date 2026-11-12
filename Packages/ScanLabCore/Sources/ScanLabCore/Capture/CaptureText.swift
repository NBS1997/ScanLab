import Foundation

/// The words and numbers the Capture screen shows and the screen reader speaks.
public enum CaptureText {
    private static let australian = Locale(identifier: "en_AU")

    /// "00:42", or "1:02:05" past an hour. Negative or impossible times show "00:00".
    public static func elapsed(_ seconds: TimeInterval) -> String {
        let whole = seconds.isFinite ? max(Int(seconds.rounded(.down)), 0) : 0
        let hours = whole / 3_600
        let minutes = (whole % 3_600) / 60
        let remainder = whole % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    /// "42 seconds", "1 minute 5 seconds", for the screen reader.
    public static func spokenElapsed(_ seconds: TimeInterval) -> String {
        let whole = seconds.isFinite ? max(Int(seconds.rounded(.down)), 0) : 0
        let minutes = whole / 60
        let remainder = whole % 60
        let secondsText = remainder == 1 ? "1 second" : "\(remainder) seconds"
        guard minutes > 0 else { return secondsText }
        let minutesText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        return remainder == 0 ? minutesText : "\(minutesText) \(secondsText)"
    }

    /// "12 areas · 34,560 faces · 85 depth pictures"; "No surface yet" before anything is
    /// reconstructed. The depth-picture count (DF-9) is left out until fusion has begun.
    public static func stats(_ progress: SweepProgress) -> String {
        guard progress.faceCount > 0 else { return "No surface yet" }
        let areas = progress.anchorCount == 1 ? "1 area" : "\(count(progress.anchorCount)) areas"
        let surface = "\(areas) · \(Units.faceCount(progress.faceCount))"
        switch progress.fusedFrames {
        case 0: return surface
        case 1: return "\(surface) · 1 depth picture"
        default: return "\(surface) · \(count(progress.fusedFrames)) depth pictures"
        }
    }

    private static func count(_ value: Int) -> String {
        value.formatted(.number.locale(australian))
    }
}
