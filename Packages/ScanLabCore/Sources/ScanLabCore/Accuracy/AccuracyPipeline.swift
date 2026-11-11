import Foundation

/// The steps of an accuracy check, as shown with the progress bar.
public enum AccuracyStep: String, Sendable {
    case sampling
    case isolating
    case aligning
    case measuring

    public var displayName: String {
        switch self {
        case .sampling: "Reading the scan"
        case .isolating: "Removing the background"
        case .aligning: "Lining up with the reference"
        case .measuring: "Measuring the surface"
        }
    }
}

/// How far an accuracy check has got: the step, and the whole job's share done (0–1).
public struct AccuracyProgress: Equatable, Sendable {
    public var step: AccuracyStep
    public var fraction: Double

    public init(step: AccuracyStep, fraction: Double) {
        self.step = step
        self.fraction = fraction
    }
}

/// Everything an accuracy check needs besides the scan.
public struct AccuracyRequest: Sendable {
    public var scanID: UUID
    public var surface: ReferenceSurface
    public var caliperValuesEntered: Int
    public var alignment: AlignmentSettings
    public var rule: ReliabilityRule
    /// How many points the scan is turned into (see `AccuracyPipeline`).
    public var scanPoints: Int
    public var createdAt: Date

    public init(scanID: UUID, surface: ReferenceSurface, caliperValuesEntered: Int = 0, createdAt: Date = Date()) {
        self.scanID = scanID
        self.surface = surface
        self.caliperValuesEntered = caliperValuesEntered
        self.alignment = AlignmentSettings()
        self.rule = ReliabilityRule()
        self.scanPoints = 20_000
        self.createdAt = createdAt
    }
}

/// The whole stage 1 check, from a scanned mesh to a report (US-13; services.md,
/// "Accuracy").
///
/// 1. **Sampling.** The scan is turned into 20,000 points spread evenly over its
///    surface (`SurfaceSampler`), whatever its size: 5,000 or 200,000 corners both give
///    the same amount of work afterwards, and every part of the surface counts equally.
///    The same seed is always used, so checking the same scan twice gives the same
///    report.
/// 2. **Isolating.** The table and anything else that is not the object is removed
///    (`ScanIsolation`).
/// 3. **Aligning.** `Alignment` lines the points up with the reference, using 200, 400
///    and 4,000 of them for its successive stages, and all of them for coverage.
/// 4. **Measuring.** `Deviation` measures every point's distance from the true surface.
/// 5. **Reporting.** `AccuracyReporting` applies the reliability rule and writes the
///    verdict.
///
/// It runs on whatever thread calls it and checks for cancellation between rounds; the
/// app runs it in the background.
public enum AccuracyPipeline {
    public static func run(
        scan: Mesh, request: AccuracyRequest, progress: (AccuracyProgress) -> Void = { _ in }
    ) throws -> AccuracyReport {
        progress(AccuracyProgress(step: .sampling, fraction: 0))
        let started = Date()
        let points = SurfaceSampler.sample(scan, count: request.scanPoints, seed: 0xACC0)
        var report = try run(points: points, request: request, progress: progress)
        report.stepMilliseconds["sampling"] = milliseconds(since: started)
        return report
    }

    /// The same, from points already on the scan's surface (used by tests to build
    /// scans with exactly known errors).
    public static func run(
        points: [SurfacePoint], request: AccuracyRequest, progress: (AccuracyProgress) -> Void = { _ in }
    ) throws -> AccuracyReport {
        var timings: [String: Int] = [:]
        var clock = Date()
        progress(AccuracyProgress(step: .isolating, fraction: 0.05))
        let isolated = ScanIsolation.isolate(points, referenceDiagonal: request.surface.diagonal)
        timings["isolating"] = milliseconds(since: clock)
        try Task.checkCancellation()

        clock = Date()
        progress(AccuracyProgress(step: .aligning, fraction: 0.1))
        let positions = isolated.points.map(\.position)
        let alignment = try Alignment.align(positions, to: request.surface, settings: request.alignment) {
            progress(AccuracyProgress(step: .aligning, fraction: 0.1 + 0.75 * $0))
        }
        timings["aligning"] = milliseconds(since: clock)

        clock = Date()
        progress(AccuracyProgress(step: .measuring, fraction: 0.85))
        let aligned = positions.map(alignment.transform.apply)
        let deviation = try Deviation.measure(
            aligned, against: request.surface, inlierDistance: request.alignment.inlierDistance)
        timings["measuring"] = milliseconds(since: clock)

        let context = ReportContext(
            scanID: request.scanID, createdAt: request.createdAt, table: request.surface.reference.table,
            rule: request.rule, caliperValuesEntered: request.caliperValuesEntered,
            inlierDistance: request.alignment.inlierDistance, coverageRadius: request.alignment.coverageRadius)
        var report = AccuracyReporting.makeReport(alignment: alignment, deviation: deviation, context: context)
        report.pointsUsed = points.count
        report.backgroundRemoved = isolated.removed
        report.stepMilliseconds = timings
        progress(AccuracyProgress(step: .measuring, fraction: 1))
        return report
    }

    private static func milliseconds(since start: Date) -> Int {
        Int((Date().timeIntervalSince(start) * 1000).rounded())
    }
}
