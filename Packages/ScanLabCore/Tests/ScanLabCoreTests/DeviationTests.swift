import Foundation
import Testing

@testable import ScanLabCore

@Suite("Surface deviation")
struct DeviationTests {
    @Test("summary figures of known distances")
    func stats() throws {
        let stats = try #require(DeviationStats([0.001, -0.003, 0.002, 0]))
        #expect(stats.count == 4)
        #expect(isClose(stats.mean, 0))
        #expect(isClose(stats.rms, (0.000014 / 4).squareRoot()))
        #expect(stats.maximum == 0.003)
        #expect(stats.within95 == 0.003)
        #expect(DeviationStats([]) == nil)
    }

    @Test("errors placed in each size class are reported in that class")
    func knownErrorsBySizeClass() throws {
        let surface = try AccuracyFixtures.surface.get()
        // Push points out by 0.3 mm on small features, in by 0.1 mm on medium ones and
        // out by 0.05 mm everywhere else; no alignment is involved.
        let samples = SurfaceSampler.sample(AccuracyFixtures.object, count: 4000, seed: 21)
        let offsets: [SizeClass: Double] = [.small: 0.0003, .medium: -0.0001, .large: 0.00005]
        let points = samples.map { sample -> Vec3 in
            let push = surface.sizeClass(at: sample.position).flatMap { offsets[$0] } ?? 0.00005
            return sample.position + sample.normal * push
        }
        let result = try Deviation.measure(points, against: surface, inlierDistance: 0.005)
        #expect(result.excluded == 0)
        let small = try #require(result.bySizeClass[.small])
        let medium = try #require(result.bySizeClass[.medium])
        let large = try #require(result.bySizeClass[.large])
        #expect(abs(small.mean - 0.0003) * 1000 < AlignmentTests.tolerance)
        #expect(abs(medium.mean + 0.0001) * 1000 < AlignmentTests.tolerance)
        #expect(abs(large.mean - 0.00005) * 1000 < AlignmentTests.tolerance)
        #expect(small.count + medium.count + large.count + (result.otherSurface?.count ?? 0) == 4000)
    }

    @Test("points far from the reference are left out and counted")
    func excludesBackground() throws {
        let surface = try AccuracyFixtures.surface.get()
        let points = [Vec3(0.06, 0.05, 0.009), Vec3(0.06, 0.05, 0.5), Vec3(2, 2, 2)]
        let result = try Deviation.measure(points, against: surface, inlierDistance: 0.005)
        #expect(result.excluded == 2)
        #expect(result.overall?.count == 1)
        #expect(isClose(result.overall?.mean ?? 0, 0.001, tolerance: 1e-12))
    }

    @Test("points inside the object have negative distances")
    func signs() throws {
        let surface = try AccuracyFixtures.surface.get()
        let result = try Deviation.measure([Vec3(0.06, 0.05, 0.007)], against: surface, inlierDistance: 0.005)
        #expect(isClose(result.overall?.mean ?? 0, -0.001, tolerance: 1e-12))
    }

    @Test("a point between feature regions is plain surface; overlapping regions pick the smallest")
    func regions() throws {
        let surface = try AccuracyFixtures.surface.get()
        #expect(surface.sizeClass(at: Vec3(0.06, 0.02, 0.013)) == .small)
        #expect(surface.sizeClass(at: Vec3(0.02, 0.06, 0.04)) == .medium)
        #expect(surface.sizeClass(at: Vec3(0.02, 0.06, 0.008)) == .medium)
        #expect(surface.sizeClass(at: Vec3(0.06, 0.05, 0.008)) == .large)
        #expect(surface.sizeClass(at: Vec3(0.02, 0.06, 0.07)) == nil)
        let result = try Deviation.measure([Vec3(0.02, 0.062, 0.0685)], against: surface, inlierDistance: 0.005)
        #expect(result.otherSurface == nil && result.bySizeClass[.medium]?.count == 1)
    }
}
