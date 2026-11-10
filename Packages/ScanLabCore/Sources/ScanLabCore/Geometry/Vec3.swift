import Foundation

/// A point or direction in 3D space. Meshes keep their positions in metres.
///
/// The parts are `Double`, not `Float`. A phone mesh of 200,000 faces costs about
/// 2.4 MB more this way, which is nothing; in return the simplifier's error sums
/// (squares of distances added up over many faces) and the metre-to-millimetre
/// conversion keep far more precision than the 0.1% the exports must hold. Files
/// that need `Float`, such as binary STL, convert at the moment of writing.
public struct Vec3: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vec3(0, 0, 0)

    public static func + (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    public static func - (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    public static prefix func - (vector: Vec3) -> Vec3 {
        Vec3(-vector.x, -vector.y, -vector.z)
    }

    public static func * (lhs: Vec3, rhs: Double) -> Vec3 {
        Vec3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    public static func * (lhs: Double, rhs: Vec3) -> Vec3 {
        rhs * lhs
    }

    public static func / (lhs: Vec3, rhs: Double) -> Vec3 {
        Vec3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }

    public func dot(_ other: Vec3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    /// The vector at right angles to both, following the right-hand rule.
    public func cross(_ other: Vec3) -> Vec3 {
        Vec3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }

    public var length: Double {
        dot(self).squareRoot()
    }

    /// The same direction with length 1, or zero when there is no direction.
    public var normalised: Vec3 {
        let size = length
        return size > 0 ? self / size : .zero
    }

    public var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }

    public func distance(to other: Vec3) -> Double {
        (self - other).length
    }

    /// The smaller of each part.
    public func componentMin(_ other: Vec3) -> Vec3 {
        Vec3(Swift.min(x, other.x), Swift.min(y, other.y), Swift.min(z, other.z))
    }

    /// The larger of each part.
    public func componentMax(_ other: Vec3) -> Vec3 {
        Vec3(Swift.max(x, other.x), Swift.max(y, other.y), Swift.max(z, other.z))
    }
}

/// An axis-aligned box: the overall size of a mesh.
public struct Box: Equatable, Sendable {
    public var minimum: Vec3
    public var maximum: Vec3

    public init(minimum: Vec3, maximum: Vec3) {
        self.minimum = minimum
        self.maximum = maximum
    }

    /// The smallest box holding every point, or `nil` when there are none.
    public init?(enclosing points: some Sequence<Vec3>) {
        var iterator = points.makeIterator()
        guard let first = iterator.next() else { return nil }
        var low = first
        var high = first
        while let point = iterator.next() {
            low = low.componentMin(point)
            high = high.componentMax(point)
        }
        self.init(minimum: low, maximum: high)
    }

    /// Width, depth and height.
    public var size: Vec3 { maximum - minimum }

    public var centre: Vec3 { (minimum + maximum) / 2 }

    /// The distance between opposite corners.
    public var diagonal: Double { size.length }

    public func contains(_ point: Vec3, tolerance: Double = 0) -> Bool {
        let low = minimum - Vec3(tolerance, tolerance, tolerance)
        let high = maximum + Vec3(tolerance, tolerance, tolerance)
        return point.componentMax(low) == point && point.componentMin(high) == point
    }
}

/// Moves, turns or resizes points: multiplies by a 3 × 3 matrix (given as its three
/// rows), then adds `translation`.
public struct Transform: Equatable, Sendable {
    public var xRow: Vec3
    public var yRow: Vec3
    public var zRow: Vec3
    public var translation: Vec3

    public init(xRow: Vec3, yRow: Vec3, zRow: Vec3, translation: Vec3 = .zero) {
        self.xRow = xRow
        self.yRow = yRow
        self.zRow = zRow
        self.translation = translation
    }

    public static let identity = Transform(xRow: Vec3(1, 0, 0), yRow: Vec3(0, 1, 0), zRow: Vec3(0, 0, 1))

    /// Resizes about the origin by the same factor in every direction.
    public static func scaling(by factor: Double) -> Transform {
        Transform(xRow: Vec3(factor, 0, 0), yRow: Vec3(0, factor, 0), zRow: Vec3(0, 0, factor))
    }

    /// Moves without turning or resizing.
    public static func moving(by offset: Vec3) -> Transform {
        Transform(xRow: Vec3(1, 0, 0), yRow: Vec3(0, 1, 0), zRow: Vec3(0, 0, 1), translation: offset)
    }

    public func apply(to point: Vec3) -> Vec3 {
        Vec3(xRow.dot(point), yRow.dot(point), zRow.dot(point)) + translation
    }

    /// Negative when the transform mirrors, which turns a mesh inside out unless its
    /// triangles are flipped as well.
    public var determinant: Double {
        xRow.dot(yRow.cross(zRow))
    }
}
