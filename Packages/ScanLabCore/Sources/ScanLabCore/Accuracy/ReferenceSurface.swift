import Foundation

/// A feature's region in metres, with its size class, for grouping surface errors.
struct FeatureRegion: Sendable {
    var sizeClass: SizeClass
    var box: Box
}

/// The reference object made ready for comparisons: its search index, its overall
/// shape and the points used to judge coverage. Building it takes a moment, so the app
/// builds it once and reuses it for every report.
public final class ReferenceSurface: Sendable {
    /// Faces whose outward direction points further down than this (as a share of
    /// straight down) are the underside. The reference object has no overhang steeper
    /// than 45 degrees (measurement sheet), so only the face it stands on points down.
    static let undersideLimit = -0.95

    public let reference: ReferenceObject
    let index: SurfaceIndex
    /// Points spread evenly over the surface a scan can see: everything except the
    /// underside, which rests on the table and is never scanned.
    let visibleSamples: [SurfacePoint]
    /// The middle of `visibleSamples`.
    let centroid: Vec3
    /// The main directions of `visibleSamples` (columns, strongest spread first).
    let axes: Matrix3
    /// The distance between opposite corners of the reference's bounding box, metres.
    let diagonal: Double
    /// Feature regions in metres, smallest size class first.
    let regions: [FeatureRegion]

    /// - Parameter sampleCount: how many points judge coverage and shape. 3,000 gives a
    ///   coverage figure good to about one percentage point.
    public init(_ reference: ReferenceObject, sampleCount: Int = 3000) throws {
        self.reference = reference
        index = SurfaceIndex(mesh: reference.mesh)
        visibleSamples = SurfaceSampler.sample(reference.mesh, count: sampleCount, seed: 0x5EED) {
            $0.z > Self.undersideLimit
        }
        guard index.triangleCount > 0, visibleSamples.count >= 3, let box = reference.mesh.boundingBox else {
            throw ReferenceError.degenerateShape
        }
        let positions = visibleSamples.map(\.position)
        centroid = LinearAlgebra.centroid(positions)
        let spread = LinearAlgebra.principalAxes(of: LinearAlgebra.covariance(positions, about: centroid))
        // A flat (or line-like) reference has no third direction to line up, so any
        // turn about its flat side would fit equally well.
        guard spread.strengths.z > 1e-6 * spread.strengths.x, spread.strengths.x > 0 else {
            throw ReferenceError.degenerateShape
        }
        axes = spread.axes
        diagonal = box.diagonal
        let metresPerMillimetre = 1 / Units.millimetresPerMetre
        regions = reference.table.features
            .map { FeatureRegion(sizeClass: $0.sizeClass, box: Self.scaled($0.region, by: metresPerMillimetre)) }
            .sorted { $0.sizeClass < $1.sizeClass }
    }

    /// The size class of the smallest feature whose region holds `point` (in reference
    /// coordinates, metres), or `nil` when the point is on plain surface between
    /// features. See business rule AC-9 for why the smallest wins.
    func sizeClass(at point: Vec3) -> SizeClass? {
        regions.first { $0.box.contains(point) }?.sizeClass
    }

    private static func scaled(_ box: Box, by factor: Double) -> Box {
        Box(minimum: box.minimum * factor, maximum: box.maximum * factor)
    }
}
