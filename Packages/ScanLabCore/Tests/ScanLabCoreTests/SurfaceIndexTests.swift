import Foundation
import Testing

@testable import ScanLabCore

@Suite("Surface search and sampling")
struct SurfaceIndexTests {
    private let corners = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0)]

    private func closest(_ point: Vec3) -> Vec3 {
        TriangleMaths.closestPoint(to: point, corners[0], corners[1], corners[2])
    }

    @Test("nearest point on a triangle: inside, beside each edge and past each corner")
    func closestPoint() {
        #expect(isClose(closest(Vec3(0.2, 0.2, 5)), Vec3(0.2, 0.2, 0)))
        #expect(isClose(closest(Vec3(-1, -1, 0)), corners[0]))
        #expect(isClose(closest(Vec3(2, -1, 0)), corners[1]))
        #expect(isClose(closest(Vec3(-1, 2, 0)), corners[2]))
        #expect(isClose(closest(Vec3(0.5, -1, 0)), Vec3(0.5, 0, 0)))
        #expect(isClose(closest(Vec3(-1, 0.5, 0)), Vec3(0, 0.5, 0)))
        #expect(isClose(closest(Vec3(1, 1, 0)), Vec3(0.5, 0.5, 0)))
    }

    @Test("the index finds the same nearest point as checking every triangle")
    func matchesBruteForce() throws {
        let mesh = AccuracyFixtures.object
        let index = SurfaceIndex(mesh: mesh)
        #expect(index.triangleCount > 0)
        var random = SeededRandom(seed: 3)
        for _ in 0..<300 {
            let point = Vec3(random.unit() * 0.16 - 0.02, random.unit() * 0.12 - 0.02, random.unit() * 0.09 - 0.01)
            let hit = try #require(index.nearest(to: point, within: 1))
            var best = Double.infinity
            for triangle in mesh.triangles {
                let spot = TriangleMaths.closestPoint(
                    to: point, mesh.vertices[triangle.a], mesh.vertices[triangle.b], mesh.vertices[triangle.c])
                best = min(best, (spot - point).length)
            }
            #expect(isClose(hit.distance, best, tolerance: 1e-12))
        }
    }

    @Test("nothing is found beyond the search limit, or in an empty mesh")
    func limit() {
        let index = SurfaceIndex(mesh: AccuracyFixtures.object)
        #expect(index.nearest(to: Vec3(0, 0, 1), within: 0.01) == nil)
        #expect(index.nearest(to: Vec3(0.05, 0.04, 0.009), within: 0.01) != nil)
        #expect(SurfaceIndex(mesh: .empty).nearest(to: .zero, within: 1) == nil)
    }

    @Test("the nearest point carries the outward direction of its face")
    func normals() throws {
        let index = SurfaceIndex(mesh: AccuracyFixtures.object)
        let top = try #require(index.nearest(to: Vec3(0.06, 0.05, 0.0085), within: 0.01))
        #expect(isClose(top.normal, Vec3(0, 0, 1)))
        let underneath = try #require(index.nearest(to: Vec3(0.06, 0.05, -0.001), within: 0.01))
        #expect(isClose(underneath.normal, Vec3(0, 0, -1)))
    }

    @Test("sampling spreads points by area, on the surface, the same way every time")
    func sampling() {
        let mesh = TestMeshes.grid(cells: 4, size: 2)
        let points = SurfaceSampler.sample(mesh, count: 4000, seed: 9)
        #expect(points.count == 4000)
        #expect(points.allSatisfy { $0.position.z == 0 && $0.normal == Vec3(0, 0, 1) })
        let leftHalf = points.filter { $0.position.x < 1 }.count
        #expect(abs(leftHalf - 2000) < 150)
        #expect(SurfaceSampler.sample(mesh, count: 50, seed: 9) == Array(points.prefix(50)))
    }

    @Test("sampling can leave faces out, and an empty mesh gives no points")
    func samplingFilter() {
        let cube = TestMeshes.cube(size: 1)
        let points = SurfaceSampler.sample(cube, count: 600, seed: 1) { $0.z > -0.95 }
        #expect(points.count == 600)
        #expect(!points.contains { $0.normal.z < -0.5 })
        #expect(SurfaceSampler.sample(.empty, count: 10, seed: 1).isEmpty)
        #expect(SurfaceSampler.sample(cube, count: 0, seed: 1).isEmpty)
    }

    @Test("an even subset takes evenly spaced items")
    func evenSubset() {
        let items = Array(0..<10)
        #expect(SurfaceSampler.evenSubset(items, count: 5) == [0, 2, 4, 6, 8])
        #expect(SurfaceSampler.evenSubset(items, count: 20) == items)
    }

    @Test("a point grid answers 'is anything near here?'")
    func pointGrid() {
        let grid = PointGrid([Vec3(0, 0, 0), Vec3(0.1, 0, 0)], cell: 0.003)
        #expect(grid.hasPoint(within: 0.003, of: Vec3(0.002, 0, 0)))
        #expect(grid.hasPoint(within: 0.003, of: Vec3(0.1, 0.0029, 0)))
        #expect(!grid.hasPoint(within: 0.003, of: Vec3(0.05, 0, 0)))
    }
}
