import Foundation
import Testing

@testable import ScanLabCore

@Suite("Mesh simplifier")
struct SimplifierTests {
    let sample = SampleMeshes.stepBlock()

    @Test("a mesh already within the target comes back unchanged")
    func alreadySmall() throws {
        let cube = TestMeshes.cube()
        #expect(try MeshSimplifier.simplify(cube, targetFaces: 12) == cube)
        #expect(try MeshSimplifier.simplify(.empty, targetFaces: 0) == .empty)
    }

    @Test("a negative target is refused")
    func negativeTarget() {
        #expect(throws: SimplifyError.invalidTarget(-1)) {
            try MeshSimplifier.simplify(TestMeshes.cube(), targetFaces: -1)
        }
    }

    @Test("a target of zero faces cannot be reached")
    func zeroTarget() {
        #expect(throws: SimplifyError.cannotReach(target: 0, reached: 12)) {
            try MeshSimplifier.simplify(TestMeshes.cube(), targetFaces: 0)
        }
    }

    @Test("a target below what the shape allows is reported, not faked")
    func belowPossible() throws {
        let tetrahedron = try TestMeshes.tetrahedron()
        #expect(throws: SimplifyError.cannotReach(target: 2, reached: 4)) {
            try MeshSimplifier.simplify(tetrahedron, targetFaces: 2)
        }
    }

    @Test("the sample reaches each target and stays closed", arguments: [10_000, 5_000])
    func reachesTarget(target: Int) throws {
        let simplified = try SampleResults.simplified(to: target)
        #expect(simplified.faceCount <= target)
        #expect(simplified.faceCount >= target - 10)
        #expect(simplified.openEdgeCount == 0)
        #expect(simplified.vertexCount < sample.vertexCount)
    }

    @Test("a simplified mesh can be simplified further")
    func further() throws {
        let simplified = try MeshSimplifier.simplify(SampleResults.light.get(), targetFaces: 1_000)
        #expect(simplified.faceCount <= 1_000)
        #expect(simplified.openEdgeCount == 0)
    }

    @Test("the overall size stays within 0.5% of the original", arguments: [10_000, 5_000])
    func keepsSize(target: Int) throws {
        let simplified = try SampleResults.simplified(to: target)
        let original = try #require(sample.boundingBox)
        let reduced = try #require(simplified.boundingBox)
        let before = [original.size.x, original.size.y, original.size.z]
        let after = [reduced.size.x, reduced.size.y, reduced.size.z]
        for axis in 0..<3 {
            #expect(abs(after[axis] - before[axis]) <= before[axis] * 0.005)
        }
        #expect(isClose(reduced.minimum, original.minimum, tolerance: 0.0001))
    }

    @Test("the volume stays within 2% of the original")
    func keepsVolume() throws {
        let simplified = try SampleResults.light.get()
        #expect(abs(simplified.volume - sample.volume) <= sample.volume * 0.02)
    }

    @Test("no vertex ends up joined to too many others")
    func valence() throws {
        let simplified = try SampleResults.light.get()
        var joined = [Set<Int>](repeating: [], count: simplified.vertexCount)
        for face in simplified.triangles {
            joined[face.a].formUnion([face.b, face.c])
            joined[face.b].formUnion([face.a, face.c])
            joined[face.c].formUnion([face.a, face.b])
        }
        // The boss top's centre starts with 48 neighbours; nothing may grow beyond that.
        let largest = joined.map(\.count).max() ?? 0
        #expect(largest <= 48)
    }

    @Test("the same mesh always simplifies to the same result")
    func deterministic() throws {
        let again = try MeshSimplifier.simplify(sample, targetFaces: 5_000)
        #expect(try again == SampleResults.light.get())
    }

    @Test("an open sheet keeps its outline")
    func openSheet() throws {
        let grid = TestMeshes.grid(cells: 20)
        let simplified = try MeshSimplifier.simplify(grid, targetFaces: 50)
        #expect(simplified.faceCount <= 50)
        let box = try #require(simplified.boundingBox)
        #expect(isClose(box.size, Vec3(1, 1, 0), tolerance: 1e-6))
        #expect(isClose(simplified.surfaceArea, 1, tolerance: 1e-6))
    }

    @Test("a large mesh simplifies in reasonable time", .timeLimit(.minutes(3)))
    func largeMesh() throws {
        let large = SampleMeshes.stepBlock(subdivisions: 4)
        #expect(large.faceCount == 79_360)
        let simplified = try MeshSimplifier.simplify(large, targetFaces: 5_000)
        #expect(simplified.faceCount <= 5_000)
    }

    @Test("errors explain themselves")
    func errorText() {
        #expect(SimplifyError.invalidTarget(-1).localizedDescription.contains("-1"))
        #expect(SimplifyError.cannotReach(target: 2, reached: 4).localizedDescription.contains("4"))
    }
}

@Suite("Error quadrics and the edge queue")
struct QuadricTests {
    @Test("the cost of a point is its squared distance from the plane, times the weight")
    func planeCost() {
        let quadric = Quadric(plane: Vec3(0, 0, 1), through: Vec3(0, 0, 2), weight: 3)
        #expect(isClose(quadric.cost(at: Vec3(5, -4, 2)), 0))
        #expect(isClose(quadric.cost(at: Vec3(1, 1, 5)), 27))
    }

    @Test("three planes meeting at a corner have that corner as their best point")
    func cornerMinimiser() throws {
        var quadric = Quadric(plane: Vec3(1, 0, 0), through: Vec3(1, 2, 3), weight: 1)
        quadric += Quadric(plane: Vec3(0, 1, 0), through: Vec3(1, 2, 3), weight: 1)
        let total = quadric + Quadric(plane: Vec3(0, 0, 1), through: Vec3(1, 2, 3), weight: 1)
        let best = try #require(total.minimiser())
        #expect(isClose(best, Vec3(1, 2, 3)))
    }

    @Test("a single plane or nothing at all has no single best point")
    func noMinimiser() {
        #expect(Quadric(plane: Vec3(0, 0, 1), through: .zero, weight: 1).minimiser() == nil)
        #expect(Quadric().minimiser() == nil)
    }

    @Test("the queue hands back entries cheapest first, ties by vertex number")
    func heapOrder() {
        var heap = EdgeHeap()
        let costs: [Double] = [5, 1, 3, 1, 4, 2]
        for (index, cost) in costs.enumerated() {
            heap.push(EdgeEntry(cost: cost, low: Int32(index), high: 99, lowStamp: 0, highStamp: 0))
        }
        #expect(heap.count == 6)
        var order: [Int32] = []
        while let entry = heap.pop() {
            order.append(entry.low)
        }
        #expect(order == [1, 3, 5, 2, 4, 0])
        #expect(heap.isEmpty)
        #expect(heap.pop() == nil)
    }
}
