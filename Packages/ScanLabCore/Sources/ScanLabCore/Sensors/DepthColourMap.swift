import Foundation

/// One mark on the depth legend: a distance and the colour drawn for it.
public struct LegendStop: Equatable, Sendable {
    public let metres: Float
    public let colour: RGBAColour

    public init(metres: Float, colour: RGBAColour) {
        self.metres = metres
        self.colour = colour
    }
}

/// Turns a distance into a colour for the depth layer: near is warm (red), far is
/// cool (blue), as design-system-mapping.md specifies. Distances outside the range
/// take the colour of the nearer end; missing readings take `invalidColour`.
public struct DepthColourMap: Equatable, Sendable {
    /// The usual range: the sensor's practical minimum to its 5 m maximum (V2).
    public static let standard = DepthColourMap(checkedNear: 0.2, far: 5)

    /// Drawn where the sensor gave no reading: a see-through grey, so gaps are visible
    /// without hiding the camera picture.
    public static let invalidColour = RGBAColour(red: 128, green: 128, blue: 128, alpha: 140)

    /// The ramp from near to far, spaced evenly across the range.
    static let ramp: [RGBAColour] = [
        RGBAColour(red: 220, green: 40, blue: 40),
        RGBAColour(red: 245, green: 140, blue: 30),
        RGBAColour(red: 240, green: 220, blue: 60),
        RGBAColour(red: 70, green: 190, blue: 90),
        RGBAColour(red: 40, green: 170, blue: 210),
        RGBAColour(red: 50, green: 70, blue: 200),
    ]

    public let nearMetres: Float
    public let farMetres: Float

    /// Returns nil unless both ends are finite, not negative, and far is beyond near.
    public init?(nearMetres: Float, farMetres: Float) {
        guard nearMetres.isFinite, farMetres.isFinite, nearMetres >= 0, farMetres > nearMetres else {
            return nil
        }
        self.init(checkedNear: nearMetres, far: farMetres)
    }

    private init(checkedNear near: Float, far: Float) {
        nearMetres = near
        farMetres = far
    }

    /// Where a distance sits in the range: 0 at near, 1 at far, clamped to 0–1.
    /// Nil when the reading is missing (NaN, infinite, zero or negative).
    public func position(forMetres metres: Float) -> Float? {
        guard DepthFrame.isValid(metres) else { return nil }
        let fraction = (metres - nearMetres) / (farMetres - nearMetres)
        return min(max(fraction, 0), 1)
    }

    public func colour(forMetres metres: Float) -> RGBAColour {
        guard let fraction = position(forMetres: metres) else { return Self.invalidColour }
        return Self.colour(atPosition: fraction)
    }

    /// Evenly spaced legend marks from near to far, including both ends. Fewer than
    /// two is raised to two.
    public func legendStops(count: Int = 5) -> [LegendStop] {
        let marks = max(count, 2)
        return (0..<marks).map { index in
            let fraction = Float(index) / Float(marks - 1)
            let metres = nearMetres + (farMetres - nearMetres) * fraction
            return LegendStop(metres: metres, colour: Self.colour(atPosition: fraction))
        }
    }

    /// The ramp colour at a position from 0 to 1, blending between the two nearest
    /// ramp colours.
    static func colour(atPosition fraction: Float) -> RGBAColour {
        let scaled = min(max(fraction, 0), 1) * Float(ramp.count - 1)
        let lower = min(Int(scaled), ramp.count - 2)
        return ramp[lower].blended(towards: ramp[lower + 1], by: scaled - Float(lower))
    }
}

/// Colours for the confidence layer: low red, medium amber, high green. A value the
/// sensor should never send takes the depth map's invalid grey.
public struct ConfidenceColourMap: Equatable, Sendable {
    public static let standard = ConfidenceColourMap()

    public init() {}

    public func colour(for level: ConfidenceLevel) -> RGBAColour {
        switch level {
        case .low: RGBAColour(red: 220, green: 40, blue: 40, alpha: 200)
        case .medium: RGBAColour(red: 245, green: 175, blue: 30, alpha: 200)
        case .high: RGBAColour(red: 60, green: 190, blue: 80, alpha: 200)
        }
    }

    public func colour(forRawValue value: UInt8) -> RGBAColour {
        guard let level = ConfidenceLevel(rawValue: value) else { return DepthColourMap.invalidColour }
        return colour(for: level)
    }
}
