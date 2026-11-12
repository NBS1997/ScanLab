import Foundation

/// The box around the part being swept (U09 part 1, ADR-030). Only the inside is fused.
///
/// The box is upright and lined up with the world's axes (the platform's world: y up,
/// metres). When the part stands on a surface, `floorHeight` is that surface's height and
/// the box's bottom sits just above it, so the surface is left out of the model.
public struct SubjectBox: Equatable, Sendable {
    public var bounds: Box
    /// The supporting surface's height, when one was found (SB-3).
    public var floorHeight: Double?
    /// True when Vision's subject outline picked the points; false for the depth-only pick.
    public var usedMask: Bool
    /// How many depth readings belonged to the subject.
    public var pointCount: Int

    public init(bounds: Box, floorHeight: Double? = nil, usedMask: Bool = false, pointCount: Int = 0) {
        self.bounds = bounds
        self.floorHeight = floorHeight
        self.usedMask = usedMask
        self.pointCount = pointCount
    }

    public var centre: Vec3 { bounds.centre }

    /// The box made `factor` times as big about its centre, keeping its bottom where it
    /// is when it stands on a surface (SB-6). Sides stay between 4 cm and 1.5 m.
    public func scaled(by factor: Double) -> SubjectBox {
        let size = bounds.size * factor
        let clamped = Vec3(
            Self.clampSide(size.x), Self.clampSide(size.y), Self.clampSide(size.z))
        let centre = bounds.centre
        var minimum = centre - clamped / 2
        var maximum = centre + clamped / 2
        if floorHeight != nil {
            let bottom = bounds.minimum.y
            minimum.y = bottom
            maximum.y = bottom + clamped.y
        }
        var result = self
        result.bounds = Box(minimum: minimum, maximum: maximum)
        return result
    }

    static let smallestSide = 0.04
    static let largestSide = 1.5

    static func clampSide(_ side: Double) -> Double {
        min(max(side, smallestSide), largestSide)
    }

    /// For the diagnostics log (SB-9).
    public var logDetails: [String: String] {
        let size = bounds.size * 1_000
        return [
            "size mm": String(format: "%.0f x %.0f x %.0f", size.x, size.y, size.z),
            "floor": floorHeight == nil ? "none" : "found",
            "mask": usedMask ? "yes" : "no",
            "readings": String(pointCount),
        ]
    }
}

/// Which parts of the colour picture belong to the tapped object, from Vision's subject
/// mask. Positions are fractions of the picture (0 to 1, across then down), in the
/// camera's own sideways orientation, the same as the depth picture.
public struct SubjectMask: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let inside: [Bool]

    /// Returns nil when the sizes do not agree.
    public init?(width: Int, height: Int, inside: [Bool]) {
        guard width > 0, height > 0, inside.count == width * height else { return nil }
        self.width = width
        self.height = height
        self.inside = inside
    }

    public func contains(across: Double, down: Double) -> Bool {
        guard across >= 0, across < 1, down >= 0, down < 1 else { return false }
        let column = min(Int(across * Double(width)), width - 1)
        let row = min(Int(down * Double(height)), height - 1)
        return inside[row * width + column]
    }

    /// How much of the picture is inside, from 0 to 1.
    public var share: Double {
        Double(inside.filter { $0 }.count) / Double(inside.count)
    }
}

/// Why a tap did not find a subject (SB-5).
public enum SubjectPickError: Error, Equatable, Sendable {
    case noDepthThere
    case tappedTheSurface
    case notEnoughPoints
    /// The camera is not running, or the tap came before the first picture.
    case notReady

    public var message: String {
        switch self {
        case .noDepthThere: "No depth there. Move closer, or tap another spot."
        case .tappedTheSurface: "That is the surface it sits on. Tap the part itself."
        case .notEnoughPoints: "Could not find the part there. Move closer, or tap another spot."
        case .notReady: "The camera is not ready yet. Try again in a moment."
        }
    }

    public var logName: String {
        switch self {
        case .noDepthThere: "no depth"
        case .tappedTheSurface: "tapped the surface"
        case .notEnoughPoints: "not enough points"
        case .notReady: "not ready"
        }
    }
}
