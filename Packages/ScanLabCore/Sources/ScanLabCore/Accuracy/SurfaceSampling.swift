import Foundation

/// A point on a surface, with the surface's outward direction there.
public struct SurfacePoint: Equatable, Sendable {
    public var position: Vec3
    public var normal: Vec3

    public init(position: Vec3, normal: Vec3) {
        self.position = position
        self.normal = normal
    }
}

/// A repeatable source of random numbers (the SplitMix64 method). The same seed always
/// gives the same numbers, so an accuracy report on the same scan always comes out the
/// same, and tests are never flaky.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// A number from 0 up to (not including) 1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}

/// Turns a mesh into points spread evenly over its surface.
///
/// **Why sample instead of using the mesh's own corners?** A scanned mesh has many
/// corners where the surface is detailed and few where it is flat, and anything from
/// 5,000 to 200,000 of them. Statistics over the corners would let the detailed parts
/// outvote the rest, and the work would grow with the scan. Picking a fixed number of
/// points, each triangle getting a share in proportion to its area, gives every square
/// millimetre of surface the same say and keeps the time per report predictable.
enum SurfaceSampler {
    /// `count` points spread evenly by area over the triangles that `include` accepts
    /// (given each triangle's outward direction). Empty when no triangle has area.
    static func sample(
        _ mesh: Mesh, count: Int, seed: UInt64, include: (Vec3) -> Bool = { _ in true }
    ) -> [SurfacePoint] {
        var faces: [Int] = []
        var runningArea: [Double] = []
        var total = 0.0
        for index in mesh.triangles.indices {
            let area = mesh.areaVector(mesh.triangles[index]).length / 2
            guard area > 0, include(mesh.faceNormal(index)) else { continue }
            total += area
            faces.append(index)
            runningArea.append(total)
        }
        guard total > 0, count > 0 else { return [] }
        var random = SeededRandom(seed: seed)
        var points: [SurfacePoint] = []
        points.reserveCapacity(count)
        for _ in 0..<count {
            // Pick a triangle with chance in proportion to its area: a random spot
            // along the running total of areas falls in each triangle's stretch.
            let target = random.unit() * total
            let chosen = faces[firstIndex(in: runningArea, notBelow: target)]
            points.append(point(on: mesh, face: chosen, random: &random))
        }
        return points
    }

    /// A random point inside one triangle, every spot equally likely. Taking the square
    /// root of the first number stops points bunching towards the first corner.
    private static func point(on mesh: Mesh, face: Int, random: inout SeededRandom) -> SurfacePoint {
        let triangle = mesh.triangles[face]
        let first = mesh.vertices[triangle.a]
        let second = mesh.vertices[triangle.b]
        let third = mesh.vertices[triangle.c]
        let spread = random.unit().squareRoot()
        let share = random.unit()
        let position = first * (1 - spread) + second * (spread * (1 - share)) + third * (spread * share)
        return SurfacePoint(position: position, normal: mesh.faceNormal(face))
    }

    /// The first position whose value is at least `target` (a binary search), or the
    /// last position.
    private static func firstIndex(in sorted: [Double], notBelow target: Double) -> Int {
        var low = 0
        var high = sorted.count - 1
        while low < high {
            let middle = (low + high) / 2
            if sorted[middle] < target {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    /// `count` of the points taken at even steps through the list, or all of them when
    /// there are not more than that. Used to give the slower steps a smaller share.
    static func evenSubset<Element>(_ items: [Element], count: Int) -> [Element] {
        guard items.count > count, count > 0 else { return items }
        let step = Double(items.count) / Double(count)
        return (0..<count).map { items[min(items.count - 1, Int(Double($0) * step))] }
    }
}
