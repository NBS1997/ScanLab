import Foundation

/// How hard alignment works. The standard values keep a report to a few seconds on the
/// phone for any scan size, because every step works on a fixed number of points
/// (see `AccuracyPipeline` for how the scan is turned into points).
public struct AlignmentSettings: Equatable, Sendable {
    /// Points used to rank the 36 starting guesses.
    public var screeningPoints = 200
    /// How many of the best-ranked guesses are refined.
    public var refinedStarts = 8
    /// Points and rounds used to refine each of those guesses roughly.
    public var coarsePoints = 400
    public var coarseIterations = 10
    /// Points and rounds used for the final, careful refinement.
    public var finePoints = 4000
    public var fineIterations = 40
    /// Scan points further than this from the reference after alignment (metres) are
    /// treated as not part of the object: they count against the inlier fraction and
    /// are left out of the error figures.
    public var inlierDistance = 0.005
    /// The closest the trimming distance ever gets during refinement (metres).
    public var smallestTrim = 0.001
    /// A reference point counts as covered when a scan point is this close (metres).
    public var coverageRadius = 0.003
    /// Fewer scan points than this cannot be aligned reliably.
    public var minimumPoints = 100

    public init() {}
}

/// Where the scan ended up and how well it fits.
public struct AlignmentResult: Equatable, Sendable {
    /// Moves scan coordinates into reference coordinates.
    public var transform: Transform
    /// Root-mean-square distance (metres) from the scan's inlier points to the
    /// reference surface. Equal to the inlier distance when there are no inliers.
    public var rmsResidual: Double
    /// The share of scan points within the inlier distance, 0 to 1.
    public var inlierFraction: Double
    /// The share of the reference's visible surface with a scan point nearby, 0 to 1.
    public var coverage: Double
    /// Refinement rounds in the final stage.
    public var iterations: Int
    /// How many starting guesses were tried.
    public var startsTried: Int
}

/// Why alignment could not run.
public enum AlignmentError: Error, Equatable, Sendable {
    case tooFewPoints(found: Int, needed: Int)
}

extension AlignmentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .tooFewPoints(let found, let needed):
            return "The scan has too little surface to compare (\(found) points; at least \(needed) are needed). "
                + "Scan the object again, closer and from more sides."
        }
    }
}

/// Lines a scan up with the reference object automatically, with no points picked by
/// the owner (FR-9.2; ADR-009).
///
/// **Step 1: rough guesses.** The scan could be lying in any position. The overall
/// shape gives a first idea: the middle of each point cloud, and its three main
/// directions (where it spreads most, next most and least, found from the covariance
/// of the points). Matching the scan's directions to the reference's gives a turn, but
/// each direction could point either way and two spreads can be nearly equal, so all
/// 24 ways of pairing the axes are tried. Because scans are saved with z up (rule
/// SL-13) and the object normally lies flat, 12 turns about the vertical, 30 degrees
/// apart, are tried as well. The 36 guesses are ranked by how close a few hundred scan
/// points land to the reference, and the best eight are refined.
///
/// **Step 2: iterative closest point (ICP), point-to-plane.** Repeat: for each scan
/// point, find the nearest point on the reference surface (using `SurfaceIndex`); then
/// work out the small turn and move that best closes the gaps measured *along the
/// surface's direction* at those nearest points; apply it. Measuring along the surface
/// direction lets flat areas slide over each other freely, so it settles in a handful
/// of rounds and lands on the surface itself rather than on sample points.
///
/// **Trimming.** Points far from the reference (leftover table, a hand, noise) would
/// pull the answer off. Each round only points within three times the middle
/// (median) distance are used, never less than 1 mm, so outliers have no say.
public enum Alignment {
    public static func align(
        _ scan: [Vec3], to surface: ReferenceSurface, settings: AlignmentSettings = AlignmentSettings(),
        progress: (Double) -> Void = { _ in }
    ) throws -> AlignmentResult {
        guard scan.count >= settings.minimumPoints else {
            throw AlignmentError.tooFewPoints(found: scan.count, needed: settings.minimumPoints)
        }
        let guesses = startingGuesses(scan, surface: surface)
        let rough = try bestRoughFit(scan, guesses: guesses, surface: surface, settings: settings, progress: progress)
        let finePoints = SurfaceSampler.evenSubset(scan, count: settings.finePoints)
        let fine = try refine(
            finePoints, from: rough, surface: surface, iterations: settings.fineIterations, settings: settings)
        progress(0.95)
        var result = fitQuality(finePoints, fit: fine, surface: surface, settings: settings)
        result.coverage = coverage(scan.map(fine.transform.apply), surface: surface, radius: settings.coverageRadius)
        result.startsTried = guesses.count
        progress(1)
        return result
    }

    /// The 36 starting guesses described above, as transforms from scan to reference.
    static func startingGuesses(_ scan: [Vec3], surface: ReferenceSurface) -> [Transform] {
        let centroid = LinearAlgebra.centroid(scan)
        let axes = LinearAlgebra.principalAxes(of: LinearAlgebra.covariance(scan, about: centroid)).axes
        // surface.axes × arrangement × axesᵀ turns the scan's k-th main direction onto
        // the reference direction the arrangement pairs it with.
        var turns = Matrix3.axisArrangements.map { surface.axes * $0 * axes.transposed }
        turns += (0..<12).map { Matrix3.rotation(axis: Vec3(0, 0, 1), angle: Double($0) * .pi / 6) }
        return turns.map { Transform(rotation: $0, translation: surface.centroid - $0 * centroid) }
    }

    /// Ranks the guesses, refines the best few roughly and returns the one that fits
    /// best.
    private static func bestRoughFit(
        _ scan: [Vec3], guesses: [Transform], surface: ReferenceSurface, settings: AlignmentSettings,
        progress: (Double) -> Void
    ) throws -> Transform {
        let screening = SurfaceSampler.evenSubset(scan, count: settings.screeningPoints)
        let cap = max(settings.inlierDistance, 0.05 * surface.diagonal)
        let ranked = guesses.map { ($0, score(screening, $0, surface: surface, cap: cap)) }.sorted { $0.1 < $1.1 }
        progress(0.1)
        let coarsePoints = SurfaceSampler.evenSubset(scan, count: settings.coarsePoints)
        let starts = ranked.prefix(max(1, settings.refinedStarts)).map(\.0)
        var best = starts[0]
        var bestScore = Double.infinity
        for (number, start) in starts.enumerated() {
            let fit = try refine(
                coarsePoints, from: start, surface: surface, iterations: settings.coarseIterations, settings: settings)
            let fitScore = score(coarsePoints, fit.transform, surface: surface, cap: settings.inlierDistance)
            if fitScore < bestScore {
                bestScore = fitScore
                best = fit.transform
            }
            progress(0.1 + 0.6 * Double(number + 1) / Double(starts.count))
        }
        return best
    }

    /// The average squared distance from the moved points to the surface, with each
    /// point's share capped at `cap` so that a few stray points cannot dominate.
    static func score(_ points: [Vec3], _ transform: Transform, surface: ReferenceSurface, cap: Double) -> Double {
        guard !points.isEmpty else { return .infinity }
        var total = 0.0
        for point in points {
            total += surface.index.nearest(to: transform.apply(to: point), within: cap)?.distanceSquared ?? cap * cap
        }
        return total / Double(points.count)
    }

    /// The share of the reference's visible surface that has a scan point within
    /// `radius` (FR-9.3; ADR-009).
    static func coverage(_ aligned: [Vec3], surface: ReferenceSurface, radius: Double) -> Double {
        guard !surface.visibleSamples.isEmpty, !aligned.isEmpty else { return 0 }
        let grid = PointGrid(aligned, cell: radius)
        let covered = surface.visibleSamples.filter { grid.hasPoint(within: radius, of: $0.position) }.count
        return Double(covered) / Double(surface.visibleSamples.count)
    }

    /// Residual and inlier share of the final fit (coverage is added by the caller).
    private static func fitQuality(
        _ points: [Vec3], fit: Fit, surface: ReferenceSurface, settings: AlignmentSettings
    ) -> AlignmentResult {
        var squares = 0.0
        var inliers = 0
        for point in points {
            let moved = fit.transform.apply(to: point)
            guard let hit = surface.index.nearest(to: moved, within: settings.inlierDistance) else { continue }
            squares += hit.distanceSquared
            inliers += 1
        }
        let rms = inliers > 0 ? (squares / Double(inliers)).squareRoot() : settings.inlierDistance
        let fraction = Double(inliers) / Double(max(points.count, 1))
        return AlignmentResult(
            transform: fit.transform, rmsResidual: rms, inlierFraction: fraction, coverage: 0,
            iterations: fit.iterations, startsTried: 0)
    }
}
