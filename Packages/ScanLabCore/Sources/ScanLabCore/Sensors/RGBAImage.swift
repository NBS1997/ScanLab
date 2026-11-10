import Foundation

/// A colour with red, green, blue and opacity, each 0–255.
public struct RGBAColour: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    /// 0 is fully transparent, 255 fully opaque.
    public var alpha: UInt8

    /// Fully transparent.
    public static let clear = RGBAColour(red: 0, green: 0, blue: 0, alpha: 0)

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// The colour a fraction `amount` (0–1) of the way from this colour to `other`.
    public func blended(towards other: RGBAColour, by amount: Float) -> RGBAColour {
        let fraction = min(max(amount, 0), 1)
        func mix(_ start: UInt8, _ end: UInt8) -> UInt8 {
            let value = Float(start) + (Float(end) - Float(start)) * fraction
            return UInt8(value.rounded())
        }
        return RGBAColour(
            red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue),
            alpha: mix(alpha, other.alpha))
    }
}

/// A quarter-turn rotation, used to turn a sensor-oriented picture to match the way
/// the phone is held.
public enum QuarterTurn: Sendable, CaseIterable {
    case none
    case clockwise
    case half
    case anticlockwise
}

/// A small picture as bytes: four per pixel (red, green, blue, opacity), row by row,
/// top row first. The app turns it into a system image to draw.
public struct RGBAImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var bytes: [UInt8]

    /// A picture filled with one colour.
    public init(width: Int, height: Int, filledWith colour: RGBAColour = .clear) {
        self.width = max(width, 0)
        self.height = max(height, 0)
        let pattern = [colour.red, colour.green, colour.blue, colour.alpha]
        bytes = Array([[UInt8]](repeating: pattern, count: self.width * self.height).joined())
    }

    public func pixel(column: Int, row: Int) -> RGBAColour? {
        guard (0..<width).contains(column), (0..<height).contains(row) else { return nil }
        let start = (row * width + column) * 4
        return RGBAColour(
            red: bytes[start], green: bytes[start + 1], blue: bytes[start + 2], alpha: bytes[start + 3])
    }

    public mutating func setPixel(column: Int, row: Int, to colour: RGBAColour) {
        guard (0..<width).contains(column), (0..<height).contains(row) else { return }
        let start = (row * width + column) * 4
        bytes[start] = colour.red
        bytes[start + 1] = colour.green
        bytes[start + 2] = colour.blue
        bytes[start + 3] = colour.alpha
    }

    /// The picture turned by a quarter-turn multiple.
    ///
    /// How the arithmetic works: turning clockwise moves the top-left pixel to the
    /// top-right, so the source pixel at (column, row) lands at
    /// (newWidth − 1 − row, column), and width and height swap. The other turns follow
    /// the same idea.
    public func rotated(_ turn: QuarterTurn) -> RGBAImage {
        if turn == .none { return self }
        let swapsSides = turn != .half
        var result = RGBAImage(width: swapsSides ? height : width, height: swapsSides ? width : height)
        for row in 0..<height {
            for column in 0..<width {
                guard let colour = pixel(column: column, row: row) else { continue }
                let target: (column: Int, row: Int)
                switch turn {
                case .none:
                    target = (column, row)
                case .clockwise:
                    target = (height - 1 - row, column)
                case .half:
                    target = (width - 1 - column, height - 1 - row)
                case .anticlockwise:
                    target = (row, width - 1 - column)
                }
                result.setPixel(column: target.column, row: target.row, to: colour)
            }
        }
        return result
    }
}
