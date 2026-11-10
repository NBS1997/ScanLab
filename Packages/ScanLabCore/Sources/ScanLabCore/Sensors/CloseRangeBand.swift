import Foundation

/// Where Explore's close-range colours are centred, and how wide the band is.
///
/// The band follows the distance at the centre of the picture, but not every small
/// wobble: if it re-centred on every reading, the colours would shimmer as the hand
/// moves. It only moves once the centre reading has drifted more than half the
/// band's half-width away (for ±5 cm, 2.5 cm), so a 2 cm step on the subject keeps
/// a steady colour while the owner looks at it.
public struct CloseRangeBand: Equatable, Sendable {
    /// The widths the owner can choose from: ±2 cm, ±5 cm and ±10 cm.
    public static let halfWidthChoices: [Float] = [0.02, 0.05, 0.10]
    /// ±5 cm: a 2 cm step then spans a fifth of the colour ramp, one full colour.
    public static let defaultHalfWidth: Float = 0.05
    /// How far, as a share of the half-width, the reading must move before the band
    /// follows it.
    public static let recentreShare: Float = 0.5

    public private(set) var halfWidth: Float
    /// Nil until the first valid reading arrives.
    public private(set) var centre: Float?

    /// A half-width that is not a positive number falls back to the default.
    public init(halfWidth: Float = defaultHalfWidth) {
        self.halfWidth = halfWidth.isFinite && halfWidth > 0 ? halfWidth : Self.defaultHalfWidth
    }

    /// Takes the latest centre reading. Returns true when the band moved. A missing
    /// reading leaves the band where it was.
    @discardableResult
    public mutating func follow(_ reading: Float?) -> Bool {
        guard let reading, DepthFrame.isValid(reading) else { return false }
        if let centre, abs(reading - centre) <= halfWidth * Self.recentreShare {
            return false
        }
        centre = reading
        return true
    }

    /// Changes the width, keeping the centre. Ignored unless a positive number.
    public mutating func setHalfWidth(_ value: Float) {
        guard value.isFinite, value > 0 else { return }
        halfWidth = value
    }

    /// The colour map for the band, or nil before any reading has arrived.
    public var colourMap: DepthColourMap? {
        centre.flatMap { DepthColourMap.closeRange(centredOn: $0, halfWidth: halfWidth) }
    }

    /// "±5 cm".
    public static func label(halfWidth: Float) -> String {
        let centimetres = (halfWidth * 100).rounded()
        return String(format: "±%.0f cm", centimetres)
    }

    /// "plus or minus 5 centimetres", for the screen reader.
    public static func spokenLabel(halfWidth: Float) -> String {
        let centimetres = Int((halfWidth * 100).rounded())
        return centimetres == 1 ? "plus or minus 1 centimetre" : "plus or minus \(centimetres) centimetres"
    }
}
