import Foundation

/// Where the owner is in choosing what to sweep (SB-1 to SB-8).
public enum SubjectStage: Equatable, Sendable {
    /// Waiting for a tap on the part.
    case choosing
    /// A tap is being turned into a box.
    case finding
    /// A box was found and is shown in yellow, waiting for Scan this.
    case proposed(SubjectBox)
    /// The box is locked: fusion runs inside it.
    case locked(SubjectBox)
    /// Scan everything was chosen: fusion runs over the whole view, as in build 7.
    case wholeScene
}

/// The rules for choosing the subject, kept apart from the screen so they can be tested.
/// Every change returns whether it was allowed; a refused change leaves everything as
/// it was.
public struct SubjectChoice: Equatable, Sendable {
    public private(set) var stage: SubjectStage = .choosing
    /// Why the last tap found nothing, shown until the next tap.
    public private(set) var lastFailure: SubjectPickError?

    public init() {}

    /// A tap starts finding, while choosing or while a box is proposed.
    @discardableResult
    public mutating func tapped() -> Bool {
        switch stage {
        case .choosing, .proposed:
            stage = .finding
            lastFailure = nil
            return true
        case .finding, .locked, .wholeScene:
            return false
        }
    }

    /// The result of a tap arrives.
    @discardableResult
    public mutating func found(_ result: Result<SubjectBox, SubjectPickError>) -> Bool {
        guard stage == .finding else { return false }
        switch result {
        case .success(let box):
            stage = .proposed(box)
        case .failure(let error):
            stage = .choosing
            lastFailure = error
        }
        return true
    }

    /// Bigger or Smaller (SB-6), only while a box is proposed.
    @discardableResult
    public mutating func resize(by factor: Double) -> Bool {
        guard case .proposed(let box) = stage, factor > 0 else { return false }
        stage = .proposed(box.scaled(by: factor))
        return true
    }

    /// Scan this: the proposed box is locked.
    @discardableResult
    public mutating func lock() -> Bool {
        guard case .proposed(let box) = stage else { return false }
        stage = .locked(box)
        return true
    }

    /// Scan everything: allowed until a box is locked.
    @discardableResult
    public mutating func chooseWholeScene() -> Bool {
        switch stage {
        case .choosing, .proposed:
            stage = .wholeScene
            lastFailure = nil
            return true
        case .finding, .locked, .wholeScene:
            return false
        }
    }

    /// The box being shown, proposed or locked.
    public var box: SubjectBox? {
        switch stage {
        case .proposed(let box), .locked(let box): box
        case .choosing, .finding, .wholeScene: nil
        }
    }

    /// True once scanning proper has begun, inside a box or over everything (SB-8).
    public var isScanning: Bool {
        switch stage {
        case .locked, .wholeScene: true
        case .choosing, .finding, .proposed: false
        }
    }

    /// The instruction shown while choosing, or nil once scanning.
    public var instruction: String? {
        switch stage {
        case .choosing:
            lastFailure?.message ?? "Tap the part you want to scan."
        case .finding:
            "Finding the part…"
        case .proposed:
            "Is the yellow box round the part? Tap Scan this, or tap the part again."
        case .locked, .wholeScene:
            nil
        }
    }
}
