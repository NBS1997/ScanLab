import Foundation

/// The "error quadric" at the heart of quadric-error-metric simplification
/// (Garland and Heckbert, 1997), in plain terms:
///
/// Every face lies on a flat plane. For any point in space we can ask "how far is
/// this point from that plane?" and square the answer. A quadric adds up those
/// squared distances for a whole set of planes, but stores the sum as just ten
/// numbers, however many planes went in. Each vertex starts with the planes of the
/// faces around it. When two vertices are merged their quadrics are simply added,
/// so the merged vertex still "remembers" every original face near it.
///
/// `cost(at:)` says how far a point is from all those remembered planes: zero on a
/// flat area or a sharp edge kept in place, larger where merging would bend the
/// shape. `minimiser()` finds the point with the smallest cost.
///
/// The ten numbers are the upper half of a symmetric 4 × 4 matrix `Q`; the cost of
/// point `v` is `[v 1] Q [v 1]ᵀ`.
struct Quadric: Equatable, Sendable {
    var q00 = 0.0
    var q01 = 0.0
    var q02 = 0.0
    var q03 = 0.0
    var q11 = 0.0
    var q12 = 0.0
    var q13 = 0.0
    var q22 = 0.0
    var q23 = 0.0
    var q33 = 0.0

    static func + (lhs: Quadric, rhs: Quadric) -> Quadric {
        var sum = lhs
        sum += rhs
        return sum
    }

    static func += (lhs: inout Quadric, rhs: Quadric) {
        lhs.q00 += rhs.q00
        lhs.q01 += rhs.q01
        lhs.q02 += rhs.q02
        lhs.q03 += rhs.q03
        lhs.q11 += rhs.q11
        lhs.q12 += rhs.q12
        lhs.q13 += rhs.q13
        lhs.q22 += rhs.q22
        lhs.q23 += rhs.q23
        lhs.q33 += rhs.q33
    }

    /// The weighted sum of squared distances from `point` to the remembered planes.
    func cost(at point: Vec3) -> Double {
        let x = point.x
        let y = point.y
        let z = point.z
        let squares = q00 * x * x + q11 * y * y + q22 * z * z + q33
        let mixed = 2 * (q01 * x * y + q02 * x * z + q12 * y * z)
        let linear = 2 * (q03 * x + q13 * y + q23 * z)
        return squares + mixed + linear
    }

    /// The point with the lowest cost, or `nil` when there is no single best point.
    ///
    /// The cost is a bowl-shaped function; its lowest point is where its slope is
    /// zero, which means solving three linear equations `A p = -b` (`A` is the top
    /// left 3 × 3 of `Q`, `b` its last column). On a flat area or along a straight
    /// edge every point on the plane or line is equally good, the equations have no
    /// single answer, and the caller picks from the edge's own points instead.
    func minimiser() -> Vec3? {
        // The inverse of A is its adjugate divided by its determinant. A is symmetric,
        // so six numbers describe the adjugate.
        let inv00 = q11 * q22 - q12 * q12
        let inv01 = q02 * q12 - q01 * q22
        let inv02 = q01 * q12 - q02 * q11
        let inv11 = q00 * q22 - q02 * q02
        let inv12 = q01 * q02 - q00 * q12
        let inv22 = q00 * q11 - q01 * q01
        let determinant = q00 * inv00 + q01 * inv01 + q02 * inv02
        // Compare with the size of the numbers themselves, so the test works the
        // same whether the mesh is in metres or millimetres.
        let scale = [q00, q01, q02, q11, q12, q22].map(abs).max() ?? 0
        guard scale > 0, abs(determinant) > 1e-9 * scale * scale * scale else { return nil }
        let x = -(inv00 * q03 + inv01 * q13 + inv02 * q23) / determinant
        let y = -(inv01 * q03 + inv11 * q13 + inv12 * q23) / determinant
        let z = -(inv02 * q03 + inv12 * q13 + inv22 * q23) / determinant
        let point = Vec3(x, y, z)
        return point.isFinite ? point : nil
    }
}

extension Quadric {
    /// The quadric of one plane, given by a unit `normal` and any `point` on it,
    /// multiplied by `weight`. A plane is `n · p + d = 0`, so `d = -n · point`.
    init(plane normal: Vec3, through point: Vec3, weight: Double) {
        let offset = -normal.dot(point)
        let a = normal.x
        let b = normal.y
        let c = normal.z
        self.init(
            q00: weight * a * a, q01: weight * a * b, q02: weight * a * c, q03: weight * a * offset,
            q11: weight * b * b, q12: weight * b * c, q13: weight * b * offset,
            q22: weight * c * c, q23: weight * c * offset, q33: weight * offset * offset)
    }
}
