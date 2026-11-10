import Foundation

/// Records what happens to a model build while ScanLab is in the background, to answer
/// requirements Open Question 3: does building carry on, or pause until the app is
/// opened again? Nobody knows until it is tried on the phone, so the app notes the
/// progress when it leaves and when it comes back, and logs the difference.
public struct BackgroundBuildObserver: Equatable, Sendable {
    /// How a build ended while the app was away.
    public enum Ending: String, Equatable, Sendable {
        case built
        case failed
        case cancelled
    }

    /// One trip to the background during a build.
    public struct Observation: Equatable, Sendable {
        /// How long the app was away.
        public var seconds: Double
        public var fractionBefore: Double
        public var fractionAfter: Double
        /// Set when the build finished, failed or was stopped while the app was away.
        public var ending: Ending?

        /// Whether progress moved while away. A change smaller than a tenth of a
        /// percent is treated as none, so rounding noise is not mistaken for work.
        public var advanced: Bool {
            ending == .built || fractionAfter - fractionBefore >= 0.001
        }

        /// One sentence for the log and the screen, for example "Away 95 s: building
        /// carried on (12% → 48%)."
        public var summary: String {
            let away = "Away \(Int(seconds.rounded())) s"
            let range = "\(PhotoBuildText.percent(fractionBefore)) → \(PhotoBuildText.percent(fractionAfter))"
            switch ending {
            case .built: return "\(away): the model finished building in the background."
            case .failed: return "\(away): building failed in the background (\(range))."
            case .cancelled: return "\(away): building was stopped in the background (\(range))."
            case nil:
                if advanced { return "\(away): building carried on (\(range))." }
                return "\(away): building paused (stayed at \(PhotoBuildText.percent(fractionBefore)))."
            }
        }

        /// The details written to the diagnostics log.
        public var logDetails: [String: String] {
            [
                "seconds": String(Int(seconds.rounded())),
                "before": PhotoBuildText.percent(fractionBefore),
                "after": PhotoBuildText.percent(fractionAfter),
                "advanced": String(advanced),
                "ending": ending?.rawValue ?? "none",
            ]
        }
    }

    private var leftAt: Date?
    private var fractionWhenLeft = 0.0
    private var ending: Ending?

    public init() {}

    /// Whether the app is away during a build right now.
    public var isAway: Bool { leftAt != nil }

    /// The app went to the background while a build was at `fraction`. Ignored when
    /// already away (the platform can report leaving twice).
    public mutating func appLeft(at date: Date, fraction: Double) {
        guard leftAt == nil else { return }
        leftAt = date
        fractionWhenLeft = fraction
        ending = nil
    }

    /// The build ended while the app was away. Ignored when the app is not away.
    public mutating func buildEnded(_ how: Ending) {
        guard leftAt != nil, ending == nil else { return }
        ending = how
    }

    /// The app came back. Returns what happened while away, or `nil` when no build was
    /// running when the app left.
    public mutating func appReturned(at date: Date, fraction: Double) -> Observation? {
        guard let leftAt else { return nil }
        let observation = Observation(
            seconds: max(date.timeIntervalSince(leftAt), 0), fractionBefore: fractionWhenLeft,
            fractionAfter: max(fraction, fractionWhenLeft), ending: ending)
        self.leftAt = nil
        ending = nil
        return observation
    }
}
