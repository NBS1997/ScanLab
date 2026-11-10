import Foundation

/// The outcome of refining one guess.
struct Fit: Sendable {
    var transform: Transform
    var iterations: Int
}

/// A scan point (already moved by the current guess) paired with the nearest point on
/// the reference.
struct PointMatch: Sendable {
    var moved: Vec3
    var target: Vec3
    var normal: Vec3
    var distance: Double
}

/// One correction found by a round of refinement, and how big it is.
struct CorrectionStep: Sendable {
    var transform: Transform
    /// Radians.
    var turn: Double
    /// Metres.
    var shift: Double
}

extension Alignment {
    /// A correction smaller than this (a ten-millionth of a radian, and a ten-thousandth
    /// of a millimetre) means the fit has settled.
    static let settledTurn = 1e-7
    static let settledShift = 1e-7

    /// Iterative closest point, point-to-plane, with trimming: see the type comment of
    /// `Alignment` for the idea. Stops after `iterations` rounds or once settled.
    static func refine(
        _ points: [Vec3], from start: Transform, surface: ReferenceSurface, iterations: Int,
        settings: AlignmentSettings
    ) throws -> Fit {
        var transform = start
        var trim = max(settings.inlierDistance * 2, surface.diagonal * 0.1)
        var rounds = 0
        while rounds < iterations {
            try Task.checkCancellation()
            rounds += 1
            let matches = match(points, transform, surface: surface, within: trim)
            guard matches.count >= 6 else { break }
            let distances = matches.map(\.distance).sorted()
            trim = min(trim, max(settings.smallestTrim, 3 * distances[distances.count / 2]))
            let kept = matches.filter { $0.distance <= trim }
            guard kept.count >= 6, let step = correction(kept, centre: surface.centroid) else { break }
            transform = transform.followed(by: step.transform)
            if step.turn < settledTurn && step.shift < settledShift { break }
        }
        return Fit(transform: transform, iterations: rounds)
    }

    /// Moves each point by `transform` and pairs it with the nearest reference point no
    /// further than `limit` away. Points with nothing that close are left out.
    static func match(
        _ points: [Vec3], _ transform: Transform, surface: ReferenceSurface, within limit: Double
    ) -> [PointMatch] {
        var matches: [PointMatch] = []
        matches.reserveCapacity(points.count)
        for point in points {
            let moved = transform.apply(to: point)
            guard let hit = surface.index.nearest(to: moved, within: limit) else { continue }
            matches.append(PointMatch(moved: moved, target: hit.point, normal: hit.normal, distance: hit.distance))
        }
        return matches
    }

    /// The small turn and move that best close the gaps, measured along the surface
    /// direction at each matched point (a least-squares solution).
    ///
    /// For a small turn ω (a vector: axis times angle) about `centre` and a move t, a
    /// moved point q goes to roughly q + ω × (q − centre) + t. Its gap along the surface
    /// direction n then becomes `gap + ω · ((q − centre) × n) + t · n`. That is a
    /// straight-line equation in the six numbers of ω and t, one per point; adding up
    /// the squares of all the gaps and finding the lowest point gives six equations in
    /// six unknowns (the "normal equations"), solved by `LinearAlgebra.solve`. A tiny
    /// amount is added to the diagonal so a shape that leaves some movement free (a
    /// sphere can turn about its centre) still gives an answer instead of failing.
    static func correction(_ matches: [PointMatch], centre: Vec3) -> CorrectionStep? {
        var normal = [Double](repeating: 0, count: 36)
        var right = [Double](repeating: 0, count: 6)
        for pair in matches {
            let arm = (pair.moved - centre).cross(pair.normal)
            let row = [arm.x, arm.y, arm.z, pair.normal.x, pair.normal.y, pair.normal.z]
            let gap = (pair.moved - pair.target).dot(pair.normal)
            for first in 0..<6 {
                right[first] -= row[first] * gap
                for second in 0..<6 {
                    normal[first * 6 + second] += row[first] * row[second]
                }
            }
        }
        let trace = (0..<6).reduce(0.0) { $0 + normal[$1 * 7] }
        for diagonal in 0..<6 {
            normal[diagonal * 7] += trace * 1e-10 + 1e-20
        }
        guard let answer = LinearAlgebra.solve(normal, right) else { return nil }
        let turnVector = Vec3(answer[0], answer[1], answer[2])
        let shift = Vec3(answer[3], answer[4], answer[5])
        let turn = Matrix3.rotation(vector: turnVector)
        // Turning about `centre` rather than the origin: q → turn (q − centre) + centre + shift.
        let transform = Transform(rotation: turn, translation: centre - turn * centre + shift)
        return CorrectionStep(transform: transform, turn: turnVector.length, shift: shift.length)
    }
}
