import Foundation

/// Why a mesh could not be simplified.
public enum SimplifyError: Error, Equatable, Sendable {
    /// The target was negative.
    case invalidTarget(Int)
    /// No further merge was possible without tearing or folding the surface;
    /// `reached` is the fewest faces that could be kept.
    case cannotReach(target: Int, reached: Int)
}

extension SimplifyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidTarget(let target):
            return "A face limit of \(target) is not possible. Choose a different detail level."
        case .cannotReach(let target, let reached):
            let limit = "the fewest possible is \(reached)"
            return "This model cannot be reduced to \(target) faces without damaging it (\(limit)). Choose more detail."
        }
    }
}

/// Reduces a mesh to at most a given number of faces while keeping its shape
/// (ADR-013, requirement FR-7.3).
///
/// How it works, in plain terms: the simplifier repeatedly picks the edge whose two
/// ends can be merged into one point with the least change to the shape, merges
/// them, and repeats until there are few enough faces. Each merge usually removes the
/// two faces that shared the edge. "Least change" is measured with error quadrics
/// (see `Quadric`): a merge on a flat area costs nothing, a merge that would round
/// off a corner costs a lot, so flat areas lose detail first and corners, edges and
/// the overall size are kept. The edges wait in a priority queue, so each step is
/// quick and the whole run takes time roughly proportional to the face count.
///
/// A merge is refused when it would tear the surface (the two ends share more
/// neighbours than the faces between them), make two faces lie on top of each other,
/// or flip a face over. Equal costs are broken by vertex number, so the same mesh
/// always gives the same result.
public enum MeshSimplifier {
    /// Returns a mesh with at most `targetFaces` faces. A mesh that is already small
    /// enough comes back unchanged.
    public static func simplify(_ mesh: Mesh, targetFaces: Int) throws -> Mesh {
        guard targetFaces >= 0 else { throw SimplifyError.invalidTarget(targetFaces) }
        if mesh.faceCount <= targetFaces { return mesh }
        guard targetFaces > 0, mesh.vertexCount < Int(Int32.max) else {
            throw SimplifyError.cannotReach(target: targetFaces, reached: mesh.faceCount)
        }
        var collapser = EdgeCollapser(mesh: mesh)
        collapser.run(targetFaces: targetFaces)
        guard collapser.liveFaces <= targetFaces else {
            throw SimplifyError.cannotReach(target: targetFaces, reached: collapser.liveFaces)
        }
        return collapser.result()
    }
}

/// Where a merged vertex would go, and how much the shape would change.
struct CollapsePlan: Sendable {
    var position: Vec3
    var cost: Double
}

/// The working state of one simplification run.
struct EdgeCollapser {
    /// How strongly the edge of an open surface is held in place compared with its
    /// faces, so scans with holes keep their outline.
    static let boundaryWeight = 1000.0
    /// A face may turn by at most about 78° in one merge (cosine 0.2); more than that
    /// is treated as folding over.
    static let minimumNormalAgreement = 0.2
    /// A merge may not leave a vertex joined to more than this many others. Without
    /// a cap, merges on a flat area all cost nothing and pile into one "hub" vertex,
    /// which makes long thin faces and slows every later step.
    static let maximumValence = 24
    /// A tiny extra cost growing with the edge's length (its fourth power, the same
    /// units as the quadric cost). It only decides between merges that are otherwise
    /// equally cheap, such as those on a flat area: short edges go first, so the
    /// faces shrink evenly instead of into one vertex.
    static let lengthWeight = 1e-3

    var positions: [Vec3]
    var quadrics: [Quadric]
    var stamps: [Int32]
    var vertexAlive: [Bool]
    var faces: [Triangle]
    var faceAlive: [Bool]
    /// For each vertex, the faces that use it. Faces removed since are skipped when
    /// read, rather than searched for and deleted.
    var vertexFaces: [[Int]]
    private(set) var liveFaces: Int
    var heap = EdgeHeap()

    init(mesh: Mesh) {
        positions = mesh.vertices
        faces = mesh.triangles
        let count = mesh.vertexCount
        quadrics = Array(repeating: Quadric(), count: count)
        stamps = Array(repeating: 0, count: count)
        vertexAlive = Array(repeating: true, count: count)
        faceAlive = Array(repeating: true, count: mesh.faceCount)
        vertexFaces = Array(repeating: [], count: count)
        liveFaces = mesh.faceCount
        for (index, face) in mesh.triangles.enumerated() {
            vertexFaces[face.a].append(index)
            vertexFaces[face.b].append(index)
            vertexFaces[face.c].append(index)
        }
        addFaceQuadrics()
        let uses = edgeUses()
        addBoundaryQuadrics(uses)
        queueInitialEdges(uses)
    }

    mutating func run(targetFaces: Int) {
        while liveFaces > targetFaces, let entry = heap.pop() {
            let low = Int(entry.low)
            let high = Int(entry.high)
            guard vertexAlive[low], vertexAlive[high] else { continue }
            guard stamps[low] == entry.lowStamp, stamps[high] == entry.highStamp else { continue }
            let plan = plan(low, high)
            guard isAcceptable(keep: low, remove: high, at: plan.position) else { continue }
            collapse(keep: low, remove: high, to: plan.position)
        }
    }

    /// The surviving faces, with unused vertices removed.
    func result() -> Mesh {
        var kept: [Triangle] = []
        kept.reserveCapacity(liveFaces)
        for index in faces.indices where faceAlive[index] {
            kept.append(faces[index])
        }
        return Mesh(unchecked: positions, triangles: kept).compacted()
    }

    // MARK: - Setting up

    /// Each face adds its own plane to its three corners, weighted by its area so
    /// that large faces matter more than slivers.
    private mutating func addFaceQuadrics() {
        for face in faces {
            let normal = areaVector(face)
            let doubleArea = normal.length
            guard doubleArea > 0 else { continue }
            let quadric = Quadric(plane: normal / doubleArea, through: positions[face.a], weight: doubleArea / 2)
            quadrics[face.a] += quadric
            quadrics[face.b] += quadric
            quadrics[face.c] += quadric
        }
    }

    /// Every edge of every face, sorted, so edges used by one face only (the border
    /// of an open surface) and the list of distinct edges are easy to find.
    private func edgeUses() -> [EdgeUse] {
        var uses: [EdgeUse] = []
        uses.reserveCapacity(faces.count * 3)
        for (index, face) in faces.enumerated() {
            uses.append(EdgeUse(key: EdgeKey(face.a, face.b), face: index))
            uses.append(EdgeUse(key: EdgeKey(face.b, face.c), face: index))
            uses.append(EdgeUse(key: EdgeKey(face.c, face.a), face: index))
        }
        uses.sort { $0.key != $1.key ? $0.key < $1.key : $0.face < $1.face }
        return uses
    }

    /// A border edge gets an extra plane standing upright along it, so merges that
    /// would pull the border inwards are expensive.
    private mutating func addBoundaryQuadrics(_ uses: [EdgeUse]) {
        var start = 0
        while start < uses.count {
            var end = start + 1
            while end < uses.count && uses[end].key == uses[start].key { end += 1 }
            if end - start == 1 {
                addBoundaryQuadric(uses[start])
            }
            start = end
        }
    }

    private mutating func addBoundaryQuadric(_ use: EdgeUse) {
        let low = use.key.low
        let high = use.key.high
        let faceNormal = areaVector(faces[use.face]).normalised
        let along = positions[high] - positions[low]
        let upright = along.cross(faceNormal).normalised
        guard upright != .zero else { return }
        let weight = Self.boundaryWeight * along.dot(along)
        let quadric = Quadric(plane: upright, through: positions[low], weight: weight)
        quadrics[low] += quadric
        quadrics[high] += quadric
    }

    private mutating func queueInitialEdges(_ uses: [EdgeUse]) {
        heap.reserve(uses.count)
        var previous: EdgeKey?
        for use in uses where use.key != previous {
            previous = use.key
            pushEdge(use.key.low, use.key.high)
        }
    }

    // MARK: - Merging

    /// Works out the best place for the merged vertex: the quadric's own best point
    /// when there is one close to the edge, otherwise whichever of the two ends or
    /// the middle changes the shape least.
    func plan(_ low: Int, _ high: Int) -> CollapsePlan {
        let quadric = quadrics[low] + quadrics[high]
        let first = positions[low]
        let second = positions[high]
        let middle = (first + second) / 2
        var candidates = [first, second, middle]
        if let best = quadric.minimiser(), best.distance(to: middle) <= first.distance(to: second) {
            candidates.insert(best, at: 0)
        }
        var chosen = CollapsePlan(position: first, cost: .infinity)
        for point in candidates {
            let cost = max(0, quadric.cost(at: point))
            if cost < chosen.cost {
                chosen = CollapsePlan(position: point, cost: cost)
            }
        }
        let lengthSquared = (second - first).dot(second - first)
        chosen.cost += Self.lengthWeight * lengthSquared * lengthSquared
        return chosen
    }

    mutating func collapse(keep: Int, remove: Int, to position: Vec3) {
        positions[keep] = position
        quadrics[keep] += quadrics[remove]
        vertexAlive[remove] = false
        for face in vertexFaces[remove] where faceAlive[face] {
            if faces[face].contains(keep) {
                // The face had both ends of the edge, so it shrinks to nothing.
                faceAlive[face] = false
                liveFaces -= 1
            } else {
                faces[face].replace(remove, with: keep)
                vertexFaces[keep].append(face)
            }
        }
        vertexFaces[remove] = []
        vertexFaces[keep].removeAll { !faceAlive[$0] }
        stamps[keep] &+= 1
        for neighbour in neighbours(of: keep) {
            pushEdge(keep, neighbour)
        }
    }

    private mutating func pushEdge(_ first: Int, _ second: Int) {
        let low = min(first, second)
        let high = max(first, second)
        guard low != high else { return }
        let entry = EdgeEntry(
            cost: plan(low, high).cost, low: Int32(truncatingIfNeeded: low), high: Int32(truncatingIfNeeded: high),
            lowStamp: stamps[low], highStamp: stamps[high])
        heap.push(entry)
    }

    // MARK: - Helpers

    func faceList(of vertex: Int) -> [Int] {
        vertexFaces[vertex].filter { faceAlive[$0] }
    }

    /// The vertices joined to `vertex` by an edge, in a fixed order.
    func neighbours(of vertex: Int) -> [Int] {
        var found: [Int] = []
        for face in faceList(of: vertex) {
            for other in faces[face].indices where other != vertex && !found.contains(other) {
                found.append(other)
            }
        }
        return found
    }

    /// Twice the face's area, pointing outwards.
    func areaVector(_ face: Triangle) -> Vec3 {
        let first = positions[face.a]
        return (positions[face.b] - first).cross(positions[face.c] - first)
    }
}

/// One face's use of one edge.
struct EdgeUse: Sendable {
    var key: EdgeKey
    var face: Int
}

extension Triangle {
    func contains(_ vertex: Int) -> Bool {
        a == vertex || b == vertex || c == vertex
    }

    mutating func replace(_ old: Int, with new: Int) {
        if a == old { a = new }
        if b == old { b = new }
        if c == old { c = new }
    }
}
