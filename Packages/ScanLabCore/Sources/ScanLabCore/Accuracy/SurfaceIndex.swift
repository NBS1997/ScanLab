import Foundation

/// The nearest place found on a surface.
struct SurfaceHit: Sendable {
    /// The nearest point on the surface.
    var point: Vec3
    /// The outward direction of the triangle that point lies on.
    var normal: Vec3
    var distanceSquared: Double

    var distance: Double { distanceSquared.squareRoot() }
}

/// Finds the nearest point on a triangle mesh to any given point, quickly.
///
/// **Why it is needed.** Alignment and deviation ask "where is the nearest point on
/// the reference surface?" tens of thousands of times per report. Checking every one
/// of the reference's ~12,000 triangles each time would be hundreds of millions of
/// checks, far too slow on a phone.
///
/// **How it works: a tree of boxes (a bounding-volume hierarchy).** The triangles are
/// split in half again and again, each time along the longest side of the group, until
/// each group holds only a few. Every group remembers the smallest box around its
/// triangles. To answer a question, the search starts at the top and skips any box
/// that is further away than the best answer found so far, because nothing inside it
/// can be nearer. Usually only a few dozen triangles are ever looked at, so each
/// question costs roughly the logarithm of the triangle count instead of all of it.
///
/// Boxes are used rather than a uniform grid because CAD shapes such as the reference
/// object have a few very large flat triangles (the plate top) next to many tiny ones
/// (the small holes): a grid would either be too coarse for the small ones or copy the
/// large ones into thousands of cells.
final class SurfaceIndex: Sendable {
    /// Leaves hold at most this many triangles.
    static let leafSize = 4

    /// Three corners per triangle, in tree order.
    private let corners: [Vec3]
    /// The outward direction of each triangle, in tree order.
    private let normals: [Vec3]
    private let nodes: [BoundsNode]

    /// Triangles with an area; slivers with none are left out.
    let triangleCount: Int

    init(mesh: Mesh) {
        var lows: [Vec3] = []
        var highs: [Vec3] = []
        var centres: [Vec3] = []
        var kept: [Int] = []
        for (index, triangle) in mesh.triangles.enumerated() {
            let first = mesh.vertices[triangle.a]
            let second = mesh.vertices[triangle.b]
            let third = mesh.vertices[triangle.c]
            guard (second - first).cross(third - first).length > 0 else { continue }
            kept.append(index)
            lows.append(first.componentMin(second).componentMin(third))
            highs.append(first.componentMax(second).componentMax(third))
            centres.append((first + second + third) / 3)
        }
        var builder = IndexBuilder(order: Array(kept.indices), centres: centres, lows: lows, highs: highs)
        if !kept.isEmpty {
            _ = builder.build(0..<kept.count)
        }
        var corners: [Vec3] = []
        var normals: [Vec3] = []
        corners.reserveCapacity(kept.count * 3)
        for position in builder.order {
            let triangle = mesh.triangles[kept[position]]
            corners += [mesh.vertices[triangle.a], mesh.vertices[triangle.b], mesh.vertices[triangle.c]]
            normals.append(mesh.faceNormal(kept[position]))
        }
        self.corners = corners
        self.normals = normals
        self.nodes = builder.nodes
        self.triangleCount = kept.count
    }

    /// The nearest point on the surface no further than `limit` away, or `nil` when
    /// there is none that close. A small limit makes the search much quicker, which
    /// is how points far from the object (the table, the room) are skipped cheaply.
    func nearest(to point: Vec3, within limit: Double) -> SurfaceHit? {
        guard !nodes.isEmpty else { return nil }
        var bestSquared = limit * limit
        var best: SurfaceHit?
        var pending: [Int] = [0]
        pending.reserveCapacity(64)
        while let index = pending.popLast() {
            let node = nodes[index]
            guard Self.boxDistanceSquared(point, node) <= bestSquared else { continue }
            if node.count > 0 {
                for triangle in node.first..<(node.first + node.count) {
                    let base = triangle * 3
                    let candidate = TriangleMaths.closestPoint(
                        to: point, corners[base], corners[base + 1], corners[base + 2])
                    let offset = candidate - point
                    let squared = offset.dot(offset)
                    if squared <= bestSquared {
                        bestSquared = squared
                        best = SurfaceHit(point: candidate, normal: normals[triangle], distanceSquared: squared)
                    }
                }
            } else {
                // Visit the nearer child first (it is pushed last), so a good answer is
                // found early and more of the other side can be skipped.
                let left = index + 1
                let right = node.right
                if Self.boxDistanceSquared(point, nodes[left]) < Self.boxDistanceSquared(point, nodes[right]) {
                    pending += [right, left]
                } else {
                    pending += [left, right]
                }
            }
        }
        return best
    }

    /// The squared distance from the point to the nearest part of the node's box;
    /// zero when the point is inside it.
    private static func boxDistanceSquared(_ point: Vec3, _ node: BoundsNode) -> Double {
        let below = node.low - point
        let above = point - node.high
        let gapX = max(below.x, 0, above.x)
        let gapY = max(below.y, 0, above.y)
        let gapZ = max(below.z, 0, above.z)
        return gapX * gapX + gapY * gapY + gapZ * gapZ
    }
}

/// One box in the tree. A leaf has `count` triangles starting at `first`; a branch has
/// `count` zero, its left child straight after it and its right child at `right`.
struct BoundsNode: Sendable {
    var low: Vec3
    var high: Vec3
    var first: Int
    var count: Int
    var right: Int
}

/// Builds the tree by repeatedly splitting the triangles at the middle of their
/// longest spread.
private struct IndexBuilder {
    var order: [Int]
    let centres: [Vec3]
    let lows: [Vec3]
    let highs: [Vec3]
    var nodes: [BoundsNode] = []

    /// Adds the node for `range` of `order` (and everything below it); returns its
    /// position.
    mutating func build(_ range: Range<Int>) -> Int {
        var low = lows[order[range.lowerBound]]
        var high = highs[order[range.lowerBound]]
        var centreLow = centres[order[range.lowerBound]]
        var centreHigh = centreLow
        for position in range {
            let item = order[position]
            low = low.componentMin(lows[item])
            high = high.componentMax(highs[item])
            centreLow = centreLow.componentMin(centres[item])
            centreHigh = centreHigh.componentMax(centres[item])
        }
        let index = nodes.count
        nodes.append(BoundsNode(low: low, high: high, first: range.lowerBound, count: range.count, right: -1))
        guard range.count > SurfaceIndex.leafSize else { return index }
        let spread = centreHigh - centreLow
        let axis = spread.x >= spread.y && spread.x >= spread.z ? 0 : (spread.y >= spread.z ? 1 : 2)
        let sorted = order[range].sorted { centres[$0].component(axis) < centres[$1].component(axis) }
        order.replaceSubrange(range, with: sorted)
        let middle = range.lowerBound + range.count / 2
        _ = build(range.lowerBound..<middle)
        let right = build(middle..<range.upperBound)
        nodes[index].count = 0
        nodes[index].right = right
        return index
    }
}

/// Geometry of single triangles.
enum TriangleMaths {
    /// The point of triangle (a, b, c) nearest to `point`, by the region test in
    /// Ericson's "Real-Time Collision Detection" (section 5.1.5). The nearest point is
    /// either a corner, a point on an edge, or a point inside the face; working out
    /// which, from a few dot products, avoids any square roots.
    static func closestPoint(to point: Vec3, _ a: Vec3, _ b: Vec3, _ c: Vec3) -> Vec3 {
        let sideB = b - a
        let sideC = c - a
        let fromA = point - a
        let alongBFromA = sideB.dot(fromA)
        let alongCFromA = sideC.dot(fromA)
        if alongBFromA <= 0 && alongCFromA <= 0 { return a }
        let fromB = point - b
        let alongBFromB = sideB.dot(fromB)
        let alongCFromB = sideC.dot(fromB)
        if alongBFromB >= 0 && alongCFromB <= alongBFromB { return b }
        let weightC = alongBFromA * alongCFromB - alongBFromB * alongCFromA
        if weightC <= 0 && alongBFromA >= 0 && alongBFromB <= 0 {
            return a + sideB * (alongBFromA / (alongBFromA - alongBFromB))
        }
        let fromC = point - c
        let alongBFromC = sideB.dot(fromC)
        let alongCFromC = sideC.dot(fromC)
        if alongCFromC >= 0 && alongBFromC <= alongCFromC { return c }
        let weightB = alongBFromC * alongCFromA - alongBFromA * alongCFromC
        if weightB <= 0 && alongCFromA >= 0 && alongCFromC <= 0 {
            return a + sideC * (alongCFromA / (alongCFromA - alongCFromC))
        }
        let weightA = alongBFromB * alongCFromC - alongBFromC * alongCFromB
        let towardsB = alongCFromB - alongBFromB
        let towardsC = alongBFromC - alongCFromC
        if weightA <= 0 && towardsB >= 0 && towardsC >= 0 {
            return b + (c - b) * (towardsB / (towardsB + towardsC))
        }
        let total = weightA + weightB + weightC
        return a + sideB * (weightB / total) + sideC * (weightC / total)
    }
}
