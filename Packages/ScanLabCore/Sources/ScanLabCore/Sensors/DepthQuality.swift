import Foundation

/// What the poor-depth hint tells the owner (owner feedback 2026-11-11).
public enum DepthAdvice: Equatable, Sendable {
    /// Depth at the centre looks usable, or there is nothing to judge: no hint.
    case good
    /// The reading is far away, or patchy at range: getting closer gives the sensor
    /// more light back and more pixels on the subject.
    case moveCloser
    /// The subject is nearer than the sensor can measure reliably.
    case moveBack

    /// The hint shown on screen, or nil for no hint.
    public var hint: String? {
        switch self {
        case .good: nil
        case .moveCloser: "Move closer"
        case .moveBack: "Move back"
        }
    }

    /// A short name for the diagnostics log.
    public var logName: String {
        switch self {
        case .good: "good"
        case .moveCloser: "move closer"
        case .moveBack: "move back"
        }
    }
}

/// The readings the poor-depth advisor looks at: a small square of depth and
/// confidence values around the centre of the picture.
///
/// It is a struct rather than two loose arrays so that later builds can add more
/// evidence (Bolt 11 adds how many camera edges are in the square) without changing
/// every caller.
public struct DepthQualityInput: Equatable, Sendable {
    /// Distances in metres; NaN, infinite, zero or negative means no reading.
    public var depths: [Float]
    /// One value per depth (0 low, 1 medium, 2 high), or empty when there are none.
    /// A list of the wrong length is treated as empty.
    public var confidence: [UInt8]
    /// The last good centre distance, if known. Used only when the square has no
    /// readings at all, to tell "too close to measure" from "too far or too dark".
    public var recentDistance: Float?

    public init(depths: [Float], confidence: [UInt8] = [], recentDistance: Float? = nil) {
        self.depths = depths
        self.confidence = confidence
        self.recentDistance = recentDistance
    }

    /// The default square is 11 × 11 depth pixels, about 4% of the frame's width:
    /// big enough to cover a small object such as a remote at arm's length, small
    /// enough not to take in the whole sofa.
    public static let defaultSide = 11

    /// Copies the square of `side` × `side` pixels at the centre of a frame.
    public static func centre(of frame: DepthFrame, side: Int = defaultSide, recentDistance: Float? = nil) -> Self {
        let size = min(max(side, 1), frame.width, frame.height)
        let firstColumn = (frame.width - size) / 2
        let firstRow = (frame.height - size) / 2
        var depths: [Float] = []
        var confidence: [UInt8] = []
        depths.reserveCapacity(size * size)
        for row in firstRow..<(firstRow + size) {
            let start = row * frame.width + firstColumn
            depths.append(contentsOf: frame.depths[start..<(start + size)])
            if frame.hasConfidence {
                confidence.append(contentsOf: frame.confidence[start..<(start + size)])
            }
        }
        return DepthQualityInput(depths: depths, confidence: confidence, recentDistance: recentDistance)
    }
}

/// Decides whether the depth at the centre is poor, and which way to move to fix it.
/// Depth only for now; camera edges join in Bolt 11.
///
/// In plain terms:
/// 1. No readings at all: if the last good reading was very close, move back;
///    otherwise move closer (too far, or a dark surface returning too little light).
/// 2. The typical reading (the median) nearer than the sensor's reliable minimum:
///    move back, however good the pixels look.
/// 3. Otherwise, the square is "poor" when too many pixels are missing or too many
///    are low-confidence. Poor and very near: move back. Poor anywhere else: move
///    closer. Not poor: no hint.
///
/// **Every threshold below is a first guess**, to be tuned from what the owner sees
/// on the phone (on-device checklist, Bolt 6).
public enum PoorDepthAdvisor {
    /// Nearer than this, the depth sensor's readings are unreliable. First guess:
    /// 20 cm, the near end of the standard colour map.
    public static let reliableMinimumMetres: Float = 0.20
    /// A poor square nearer than this is taken as "too close" rather than "too dark".
    /// First guess: 30 cm.
    public static let poorAndNearMetres: Float = 0.30
    /// Poor when at least this share of the square has no reading. First guess: 30%.
    public static let missingShareLimit: Float = 0.30
    /// Poor when at least this share of the readings is low-confidence. First guess:
    /// half.
    public static let lowConfidenceShareLimit: Float = 0.50

    public static func advice(for input: DepthQualityInput) -> DepthAdvice {
        guard !input.depths.isEmpty else { return .good }
        let hasConfidence = input.confidence.count == input.depths.count
        var valid: [Float] = []
        var lowConfidence = 0
        for (index, metres) in input.depths.enumerated() where DepthFrame.isValid(metres) {
            valid.append(metres)
            if hasConfidence && input.confidence[index] == ConfidenceLevel.low.rawValue {
                lowConfidence += 1
            }
        }
        guard let typical = CentreSampler.median(of: valid) else {
            let recent = input.recentDistance ?? .infinity
            return recent < poorAndNearMetres ? .moveBack : .moveCloser
        }
        if typical < reliableMinimumMetres {
            return .moveBack
        }
        let missingShare = 1 - Float(valid.count) / Float(input.depths.count)
        let lowShare = Float(lowConfidence) / Float(valid.count)
        let isPoor = missingShare >= missingShareLimit || lowShare >= lowConfidenceShareLimit
        guard isPoor else { return .good }
        return typical < poorAndNearMetres ? .moveBack : .moveCloser
    }
}

/// Holds back a changing value until it has stayed the same for a while, so a hint
/// does not flicker on and off as the hand wobbles, and the log records only real
/// changes.
public struct SteadyValue<Value: Equatable & Sendable>: Sendable {
    /// How long a new value must persist before it is shown.
    public let holdSeconds: TimeInterval
    /// The value currently shown.
    public private(set) var shown: Value
    private var candidate: Value
    private var candidateSince: TimeInterval?

    public init(_ initial: Value, holdSeconds: TimeInterval) {
        self.holdSeconds = max(holdSeconds, 0)
        shown = initial
        candidate = initial
    }

    /// Records the latest value at time `now` (seconds on any steady clock). Returns
    /// true when the shown value changed.
    @discardableResult
    public mutating func update(_ value: Value, at now: TimeInterval) -> Bool {
        if value == shown {
            candidate = value
            candidateSince = nil
            return false
        }
        if value != candidate || candidateSince == nil {
            candidate = value
            candidateSince = now
        }
        guard let since = candidateSince, now - since >= holdSeconds else { return false }
        shown = value
        candidateSince = nil
        return true
    }
}
