import Foundation

/// The words the photo capture screen shows while building and afterwards (FR-4.3,
/// FR-6.6). Kept in Core so the wording is tested in the build.
public enum PhotoBuildText {
    /// After this long without a progress report the screen says it is still working,
    /// so the owner never sees a frozen bar for more than 10 seconds (FR-4.3).
    public static let staleAfter: TimeInterval = 10

    /// "42%". Rounded down, so 100% only shows when the build is truly finished.
    public static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "0%" }
        let clamped = min(max(fraction, 0), 1)
        return "\(Int((clamped * 100).rounded(.down)))%"
    }

    /// "Building model: 42%".
    public static func headline(_ progress: BuildProgress) -> String {
        "Building model: \(percent(progress.fraction))"
    }

    /// "Now lining up the photos", or "Starting" before the platform names a stage.
    public static func stage(_ stage: BuildStage?) -> String {
        guard let stage else { return "Starting" }
        return "Now " + stage.displayName
    }

    /// "About 3 min left", "Less than a minute left", or `nil` when the platform gave
    /// no estimate.
    public static func remaining(_ seconds: Double?) -> String? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        if seconds < 60 { return "Less than a minute left" }
        let minutes = Int((seconds / 60).rounded())
        return minutes == 1 ? "About 1 min left" : "About \(minutes) min left"
    }

    /// "Still working. Last update 25 s ago." once no report has come for
    /// `staleAfter` seconds; otherwise `nil`.
    public static func staleNotice(_ progress: BuildProgress, now: Date) -> String? {
        let waited = now.timeIntervalSince(progress.updatedAt)
        guard waited >= staleAfter else { return nil }
        return "Still working. Last update \(Int(waited)) s ago."
    }

    /// What the screen reader says for the progress bar: "42 percent, now making the
    /// mesh, about 3 min left".
    public static func spoken(_ progress: BuildProgress) -> String {
        let stageText = stage(progress.stage)
        // Only the first letter is lowered, so "3D" stays as it is.
        let spokenStage = stageText.prefix(1).lowercased() + stageText.dropFirst()
        var parts = ["\(percent(progress.fraction).dropLast()) percent", spokenStage]
        if let left = remaining(progress.secondsRemaining) {
            parts.append(left.lowercased())
        }
        return parts.joined(separator: ", ")
    }

    /// "64 photos". The shot counter during capture.
    public static func photos(_ count: Int) -> String {
        count == 1 ? "1 photo" : "\(max(count, 0)) photos"
    }

    /// The keep-or-discard question's title (FR-6.6).
    public static let keepTitle = "Keep the raw capture?"

    /// The question's message, naming the storage used: "The 64 photos and camera
    /// positions use 412 MB. Keep them to export later, or discard them to free the
    /// space. The model is saved either way."
    public static func keepMessage(_ offer: KeepOffer) -> String {
        "The \(photos(offer.images)) and camera positions use \(Units.storage(offer.rawBytes)). "
            + "Keep them to export later, or discard them to free the space. The model is saved either way."
    }

    /// "Keep (412 MB)". The button that keeps the raw capture.
    public static func keepButton(_ offer: KeepOffer) -> String {
        "Keep (\(Units.storage(offer.rawBytes)))"
    }

    /// The closing message, for example "Saved “Photos 11 Nov 14:05”. Raw capture kept
    /// (412 MB)."
    public static func done(_ outcome: PhotoCaptureOutcome) -> String {
        let saved = "Saved \u{201C}\(outcome.scanName)\u{201D}."
        guard let kept = outcome.keptRawBytes else { return saved + " Raw capture discarded." }
        return saved + " Raw capture kept (\(Units.storage(kept)))."
    }

    /// The detail line on screen: "Detail level: reduced (the only level the phone
    /// offers)" (FR-4.2).
    public static func detail(_ level: PhotoDetailLevel) -> String {
        if level == .reduced { return "Detail level: reduced (the only level iPhone offers)" }
        return "Detail level: \(level.manifestValue)"
    }
}
