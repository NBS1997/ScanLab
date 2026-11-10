import Foundation

/// A cube of space in a `PointGrid`, named by its whole-number position.
struct GridKey: Hashable, Sendable {
    var x: Int
    var y: Int
    var z: Int

    init(_ point: Vec3, cell: Double) {
        x = Int((point.x / cell).rounded(.down))
        y = Int((point.y / cell).rounded(.down))
        z = Int((point.z / cell).rounded(.down))
    }

    init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// This cube and the 26 that touch it.
    var neighbourhood: [GridKey] {
        var keys: [GridKey] = []
        keys.reserveCapacity(27)
        for stepX in -1...1 {
            for stepY in -1...1 {
                for stepZ in -1...1 {
                    keys.append(GridKey(x: x + stepX, y: y + stepY, z: z + stepZ))
                }
            }
        }
        return keys
    }
}

/// Points sorted into equal cubes of space, so "is there a point near here?" only has
/// to look in the 27 cubes around the spot instead of at every point.
struct PointGrid {
    let cell: Double
    private(set) var cells: [GridKey: [Vec3]] = [:]

    init(_ points: [Vec3], cell: Double) {
        self.cell = cell
        for point in points {
            cells[GridKey(point, cell: cell), default: []].append(point)
        }
    }

    /// Whether any point lies within `radius` of `centre`. `radius` must not be more
    /// than the cell size, or nearby cubes would be missed.
    func hasPoint(within radius: Double, of centre: Vec3) -> Bool {
        let limit = radius * radius
        for key in GridKey(centre, cell: cell).neighbourhood {
            guard let points = cells[key] else { continue }
            if points.contains(where: { ($0 - centre).dot($0 - centre) <= limit }) {
                return true
            }
        }
        return false
    }
}

/// What background removal did.
public struct IsolationResult: Sendable {
    /// The points kept: those believed to be the object.
    public var points: [SurfacePoint]
    /// How many points were dropped as table, floor or other things.
    public var removed: Int
    /// The height of the table found under the object, metres, if one was removed.
    public var supportHeight: Double?
}

/// Separates the object from the rest of a scan (business rule AC-6).
///
/// A sweep scan records everything in view: the table, perhaps the floor and other
/// things nearby. Lining those up with the reference would be hopeless, so before
/// alignment:
///
/// 1. **Is there anything to remove?** If the scan is no bigger than one and a half
///    times the reference object, it is taken to be the object alone.
/// 2. **Remove the table.** Scans are saved with z pointing up (rule SL-13), so the
///    table is the most common height among upward-facing points. Everything up to
///    2 mm above that height is dropped.
/// 3. **Keep the object.** The remaining points are sorted into 5 mm cubes, and cubes
///    that touch are joined into separate pieces. The biggest piece whose size is
///    between 0.3 and 1.5 times the reference's is the object.
///
/// If no piece fits, the points left after step 2 are used, and the reliability rule
/// will judge the result.
enum ScanIsolation {
    static let sizeAllowance = 1.5
    static let tableClearance = 0.002
    static let pieceCell = 0.005

    static func isolate(_ points: [SurfacePoint], referenceDiagonal: Double) -> IsolationResult {
        guard let box = Box(enclosing: points.map(\.position)), box.diagonal > referenceDiagonal * sizeAllowance else {
            return IsolationResult(points: points, removed: 0, supportHeight: nil)
        }
        var kept = points
        let table = supportHeight(points)
        if let table {
            kept = kept.filter { $0.position.z > table + tableClearance }
        }
        if let piece = largestPiece(kept, referenceDiagonal: referenceDiagonal) {
            kept = piece
        }
        return IsolationResult(points: kept, removed: points.count - kept.count, supportHeight: table)
    }

    /// The height with the most upward-facing points, in 5 mm steps, refined to the
    /// middle value of the points in that step. `nil` when nothing faces up.
    static func supportHeight(_ points: [SurfacePoint]) -> Double? {
        let upward = points.filter { $0.normal.z > 0.9 }.map(\.position.z)
        guard !upward.isEmpty else { return nil }
        let step = 0.005
        var counts: [Int: Int] = [:]
        for height in upward {
            counts[Int((height / step).rounded(.down)), default: 0] += 1
        }
        // Most points wins; on a tie, the lower height (the table is below the object).
        let ranked = counts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }
        guard let busiest = ranked else { return nil }
        let inStep = upward.filter { Int(($0 / step).rounded(.down)) == busiest.key }.sorted()
        return inStep[inStep.count / 2]
    }

    /// The biggest connected piece of a plausible size, or `nil` when none is.
    private static func largestPiece(_ points: [SurfacePoint], referenceDiagonal: Double) -> [SurfacePoint]? {
        var members: [GridKey: [Int]] = [:]
        for (index, point) in points.enumerated() {
            members[GridKey(point.position, cell: pieceCell), default: []].append(index)
        }
        var visited = Set<GridKey>()
        var best: [Int]?
        for start in members.keys where !visited.contains(start) {
            let piece = connectedPiece(from: start, members: members, visited: &visited)
            guard let box = Box(enclosing: piece.map { points[$0].position }) else { continue }
            let plausible = box.diagonal >= referenceDiagonal * 0.3 && box.diagonal <= referenceDiagonal * sizeAllowance
            if plausible && piece.count > (best?.count ?? 0) {
                best = piece
            }
        }
        return best.map { $0.sorted().map { points[$0] } }
    }

    /// Every point in cubes reachable from `start` through touching occupied cubes (a
    /// flood fill).
    private static func connectedPiece(
        from start: GridKey, members: [GridKey: [Int]], visited: inout Set<GridKey>
    ) -> [Int] {
        var piece: [Int] = []
        var pending = [start]
        visited.insert(start)
        while let key = pending.popLast() {
            piece += members[key] ?? []
            for next in key.neighbourhood where members[next] != nil && !visited.contains(next) {
                visited.insert(next)
                pending.append(next)
            }
        }
        return piece
    }
}
