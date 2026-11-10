import Foundation

/// Summary figures for a group of signed surface distances, all in metres.
public struct DeviationStats: Equatable, Sendable {
    public var count: Int
    /// The average signed distance: positive means the scan sits outside the true
    /// surface on average (a bulge, or an object scanned too big).
    public var mean: Double
    /// Root mean square: a typical size of the error, whatever its sign.
    public var rms: Double
    /// 95% of points are no further than this from the true surface, either side.
    public var within95: Double
    /// The furthest point, either side.
    public var maximum: Double

    /// The figures for `distances`, or `nil` when there are none.
    public init?(_ distances: [Double]) {
        guard !distances.isEmpty else { return nil }
        let sizes = distances.map(abs).sorted()
        let count = Double(distances.count)
        self.count = distances.count
        mean = distances.reduce(0, +) / count
        rms = (distances.reduce(0) { $0 + $1 * $1 } / count).squareRoot()
        // The nearest-rank 95th percentile: the value 95% of the way along the sorted list.
        within95 = sizes[Int((0.95 * Double(sizes.count - 1)).rounded())]
        maximum = sizes[sizes.count - 1]
    }
}

/// Surface error overall and by size class.
public struct DeviationResult: Equatable, Sendable {
    /// Every inlier point.
    public var overall: DeviationStats?
    /// Points whose nearest reference point lies in a feature region of each class.
    public var bySizeClass: [SizeClass: DeviationStats]
    /// Points on plain surface between the feature regions.
    public var otherSurface: DeviationStats?
    /// Points further than the inlier distance, left out of every figure.
    public var excluded: Int
}

/// How far the aligned scan's surface is from the true shape (FR-9.6 stage 1, FR-9.9).
///
/// For every aligned scan point the nearest point on the reference surface is found
/// (`SurfaceIndex`). The distance gets a sign from the reference surface's outward
/// direction there: positive when the scan point is outside the object, negative when
/// inside. Points further away than the inlier distance are not part of the object
/// (leftover background) and are left out.
///
/// Each point is then put in a size class by where its nearest reference point lies
/// (business rule AC-9): inside a feature region from the feature table, the size
/// class of the smallest such feature; otherwise "other surface". These are surface
/// distances, not feature sizes: a hole scanned 0.3 mm too small shows here as points
/// about 0.15 mm inside the surface around the hole.
public enum Deviation {
    public static func measure(
        _ aligned: [Vec3], against surface: ReferenceSurface, inlierDistance: Double
    ) throws -> DeviationResult {
        var all: [Double] = []
        var grouped: [SizeClass: [Double]] = [:]
        var other: [Double] = []
        all.reserveCapacity(aligned.count)
        for (number, point) in aligned.enumerated() {
            if number % 4096 == 0 { try Task.checkCancellation() }
            guard let hit = surface.index.nearest(to: point, within: inlierDistance) else { continue }
            let signed = (point - hit.point).dot(hit.normal) >= 0 ? hit.distance : -hit.distance
            all.append(signed)
            if let sizeClass = surface.sizeClass(at: hit.point) {
                grouped[sizeClass, default: []].append(signed)
            } else {
                other.append(signed)
            }
        }
        return DeviationResult(
            overall: DeviationStats(all), bySizeClass: grouped.compactMapValues { DeviationStats($0) },
            otherSurface: DeviationStats(other), excluded: aligned.count - all.count)
    }
}
