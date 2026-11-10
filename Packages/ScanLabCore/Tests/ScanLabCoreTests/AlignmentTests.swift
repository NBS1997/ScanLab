import Foundation
import Testing

@testable import ScanLabCore

/// The proof the Bolt is judged on (FR-9.9, US-13): synthetic scans with a known
/// position and a known built-in error are lined up and measured, and the figures
/// must come out right to within 0.05 mm.
@Suite("Alignment and the synthetic accuracy proof")
struct AlignmentTests {
    /// The tolerance FR-9.9 sets, in millimetres.
    static let tolerance = 0.05

    @Test("a scan anywhere in the room is lined up exactly, with no help")
    func recoversTransform() throws {
        let surface = try AccuracyFixtures.surface.get()
        let scan = AccuracyFixtures.scan(
            of: AccuracyFixtures.object, count: 6000, transform: AccuracyFixtures.misplacement)
        let result = try Alignment.align(
            scan.points.map(\.position), to: surface, settings: AccuracyFixtures.quickSettings)
        let aligned = scan.points.map { result.transform.apply(to: $0.position) }
        #expect(AccuracyFixtures.largestGapMillimetres(aligned, scan.truth) < Self.tolerance)
        let expected = AccuracyFixtures.misplacement.rigidInverse.rotation
        #expect(result.transform.rotation.angle(to: expected) < 1e-4)
        #expect(result.rmsResidual * 1000 < 0.01)
        #expect(result.inlierFraction > 0.99)
        #expect(result.coverage > 0.9)
        #expect(result.startsTried == 36)
    }

    @Test("a scan 0.2 mm too big all round is reported 0.2 mm out, overall and in every size class")
    func knownOffset() throws {
        let surface = try AccuracyFixtures.surface.get()
        let scan = AccuracyFixtures.scan(
            of: AccuracyFixtures.object, count: 3000, offset: 0.0002, transform: AccuracyFixtures.misplacement)
        let report = try AccuracyPipeline.run(points: scan.points, request: AccuracyFixtures.request(surface))
        #expect(report.isReliable)
        let overall = try #require(report.overall)
        #expect(abs(overall.meanMillimetres - 0.2) < Self.tolerance)
        #expect(abs(overall.rmsMillimetres - 0.2) < Self.tolerance)
        #expect(Set(report.sizeClasses.compactMap(\.sizeClass)) == Set(SizeClass.allCases))
        for row in report.sizeClasses {
            #expect(abs(row.meanMillimetres - 0.2) < Self.tolerance, "\(row.label)")
        }
    }

    @Test("noise of 0.25 mm is reported as 0.25 mm RMS with no bias")
    func knownNoise() throws {
        let surface = try AccuracyFixtures.surface.get()
        let scan = AccuracyFixtures.scan(
            of: AccuracyFixtures.object, count: 3000, noise: 0.00025, transform: AccuracyFixtures.misplacement)
        let report = try AccuracyPipeline.run(points: scan.points, request: AccuracyFixtures.request(surface))
        let overall = try #require(report.overall)
        #expect(abs(overall.rmsMillimetres - 0.25) < Self.tolerance)
        #expect(abs(overall.meanMillimetres) < Self.tolerance)
        // About 95% of a normal spread lies within 1.96 standard deviations.
        #expect(abs(overall.within95Millimetres - 0.49) < 0.05)
        #expect(report.match.quality == .good)
        #expect(report.verdictLevel == .good)
    }

    @Test("a scan with a table and clutter around the object is still found and lined up")
    func background() throws {
        let surface = try AccuracyFixtures.surface.get()
        let placement = Transform(
            rotation: Matrix3.rotation(axis: Vec3(0, 0, 1), angle: 0.7), translation: Vec3(1.2, -0.4, 0.75))
        let object = AccuracyFixtures.scan(of: AccuracyFixtures.object, count: 3000, transform: placement)
        let table = SurfaceSampler.sample(
            AccuracyFixtures.floor(size: 0.6, height: 0.75, centre: Vec3(1.2, -0.4, 0)), count: 6000, seed: 5)
        let clutter = SurfaceSampler.sample(
            AccuracyFixtures.box(from: Vec3(1.45, -0.1, 0.75), to: Vec3(1.49, -0.06, 0.79)), count: 800, seed: 6)
        let isolated = ScanIsolation.isolate(object.points + table + clutter, referenceDiagonal: surface.diagonal)
        #expect(isolated.supportHeight.map { abs($0 - 0.75) < 0.001 } == true)
        #expect(isolated.removed >= 6800)
        let result = try Alignment.align(
            isolated.points.map(\.position), to: surface, settings: AccuracyFixtures.quickSettings)
        let aligned = object.points.map { result.transform.apply(to: $0.position) }
        #expect(AccuracyFixtures.largestGapMillimetres(aligned, object.truth) < Self.tolerance)
    }

    @Test("an object-sized scan is left as it is")
    func noIsolationNeeded() {
        let points = AccuracyFixtures.scan(of: AccuracyFixtures.object, count: 200).points
        let result = ScanIsolation.isolate(points, referenceDiagonal: 0.16)
        #expect(result.removed == 0 && result.supportHeight == nil && result.points == points)
    }

    @Test("too few points cannot be aligned")
    func tooFewPoints() throws {
        let surface = try AccuracyFixtures.surface.get()
        #expect(throws: AlignmentError.tooFewPoints(found: 0, needed: 100)) {
            try Alignment.align([], to: surface)
        }
        let few = AccuracyFixtures.scan(of: AccuracyFixtures.object, count: 40).points.map(\.position)
        #expect(throws: AlignmentError.tooFewPoints(found: 40, needed: 100)) {
            try Alignment.align(few, to: surface)
        }
        #expect(AlignmentError.tooFewPoints(found: 1, needed: 2).errorDescription?.contains("1 points") == true)
    }

    @Test("a flat or empty reference is refused")
    func degenerateReference() throws {
        let flat = ReferenceObject(mesh: TestMeshes.grid(cells: 2, size: 0.1), table: FeatureTable(features: []))
        #expect(throws: ReferenceError.degenerateShape) { try ReferenceSurface(flat) }
        let empty = ReferenceObject(mesh: .empty, table: FeatureTable(features: []))
        #expect(throws: ReferenceError.degenerateShape) { try ReferenceSurface(empty) }
    }

    @Test("the real reference object, scanned from above at any angle, is lined up exactly")
    func realObject() throws {
        let reference = try AccuracyFixtures.realReference.get()
        let surface = try ReferenceSurface(reference, sampleCount: 1500)
        // Like a real scan: only what can be seen with the object on a table.
        let seen = SurfaceSampler.sample(reference.mesh, count: 2500, seed: 11) { $0.z > -0.95 }
        let placed = seen.map { AccuracyFixtures.misplacement.apply(to: $0.position) }
        let result = try Alignment.align(placed, to: surface, settings: AccuracyFixtures.quickSettings)
        let aligned = placed.map(result.transform.apply)
        #expect(AccuracyFixtures.largestGapMillimetres(aligned, seen.map(\.position)) < Self.tolerance)
        #expect(result.inlierFraction > 0.99)
    }
}
