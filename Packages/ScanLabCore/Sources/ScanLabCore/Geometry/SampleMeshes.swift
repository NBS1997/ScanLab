import Foundation

/// Built-in models with known sizes, so export can be tried on the phone before any
/// scanning exists (unit U04), and so tests have something realistic to work on.
public enum SampleMeshes {
    public static let stepBlockName = "Sample stepped block"

    /// The stepped block's overall size in metres: 60 × 40 × 20 mm.
    public static let stepBlockSize = Vec3(0.060, 0.040, 0.020)

    /// A closed, watertight stepped block with a round boss, in metres:
    ///
    /// - a base 60 mm long (x), 40 mm deep (y) and 10 mm high (z);
    /// - a step 20 mm long along the left end, rising to 15 mm;
    /// - a round boss 16 mm across, centred at x = 40 mm, y = 20 mm, rising to 20 mm.
    ///
    /// Overall 60 × 40 × 20 mm. The coarse shape has 310 faces; each subdivision
    /// splits every face into four, so the default of 3 gives 19,840 faces, enough
    /// that both reduced export levels have work to do.
    public static func stepBlock(subdivisions: Int = 3) -> Mesh {
        var builder = MeshBuilder()
        StepBlock.addBlock(to: &builder)
        StepBlock.addSurround(to: &builder)
        StepBlock.addBoss(to: &builder)
        return subdivided(builder.mesh, times: subdivisions).scaled(by: 1 / Units.millimetresPerMetre)
    }

    /// Splits every face into four by joining the midpoints of its edges, `times`
    /// times. The shape does not change; a closed mesh stays closed, because faces
    /// that share an edge share its midpoint.
    public static func subdivided(_ mesh: Mesh, times: Int) -> Mesh {
        var current = mesh
        for _ in 0..<max(0, times) {
            current = subdividedOnce(current)
        }
        return current
    }

    private static func subdividedOnce(_ mesh: Mesh) -> Mesh {
        var vertices = mesh.vertices
        var midpoints: [EdgeKey: Int] = [:]
        func midpoint(_ first: Int, _ second: Int) -> Int {
            let key = EdgeKey(first, second)
            if let existing = midpoints[key] { return existing }
            vertices.append((vertices[first] + vertices[second]) / 2)
            midpoints[key] = vertices.count - 1
            return vertices.count - 1
        }
        var triangles: [Triangle] = []
        triangles.reserveCapacity(mesh.faceCount * 4)
        for face in mesh.triangles {
            let abMid = midpoint(face.a, face.b)
            let bcMid = midpoint(face.b, face.c)
            let caMid = midpoint(face.c, face.a)
            triangles.append(Triangle(face.a, abMid, caMid))
            triangles.append(Triangle(abMid, face.b, bcMid))
            triangles.append(Triangle(caMid, bcMid, face.c))
            triangles.append(Triangle(abMid, bcMid, caMid))
        }
        return Mesh(unchecked: vertices, triangles: triangles)
    }
}

/// The pieces of the stepped block, in millimetres.
private enum StepBlock {
    static let length = 60.0
    static let depth = 40.0
    static let baseHeight = 10.0
    static let stepEnd = 20.0
    static let stepHeight = 15.0
    static let bossCentre = Vec3(40, 20, 10)
    static let bossRadius = 8.0
    static let bossTop = 20.0
    /// Points around the boss. A multiple of 8, so the square ring below has points
    /// exactly at its corners.
    static let segments = 48
    /// Half the width of the square ring of points between the boss and the edges of
    /// the face it stands on.
    static let ringHalfWidth = 14.0

    static let upward = Vec3(0, 0, 1)

    /// The flat outer faces: bottom, ends, step top, step riser, front and back.
    static func addBlock(to builder: inout MeshBuilder) {
        let base = baseHeight
        let step = stepHeight
        let end = stepEnd
        let bottom = [Vec3(0, 0, 0), Vec3(length, 0, 0), Vec3(length, depth, 0), Vec3(0, depth, 0)]
        let leftEnd = [Vec3(0, 0, 0), Vec3(0, depth, 0), Vec3(0, depth, step), Vec3(0, 0, step)]
        let rightEnd = [Vec3(length, 0, 0), Vec3(length, depth, 0), Vec3(length, depth, base), Vec3(length, 0, base)]
        let stepTop = [Vec3(0, 0, step), Vec3(end, 0, step), Vec3(end, depth, step), Vec3(0, depth, step)]
        let riser = [Vec3(end, 0, base), Vec3(end, depth, base), Vec3(end, depth, step), Vec3(end, 0, step)]
        builder.quad(bottom, outward: -upward)
        builder.quad(leftEnd, outward: Vec3(-1, 0, 0))
        builder.quad(rightEnd, outward: Vec3(1, 0, 0))
        builder.quad(stepTop, outward: upward)
        builder.quad(riser, outward: Vec3(1, 0, 0))
        addProfile(atDepth: 0, outward: Vec3(0, -1, 0), to: &builder)
        addProfile(atDepth: depth, outward: Vec3(0, 1, 0), to: &builder)
    }

    /// The L-shaped front or back face, as a fan of triangles from its first corner.
    private static func addProfile(atDepth y: Double, outward: Vec3, to builder: inout MeshBuilder) {
        let outline = [
            Vec3(0, y, 0), Vec3(length, y, 0), Vec3(length, y, baseHeight),
            Vec3(stepEnd, y, baseHeight), Vec3(stepEnd, y, stepHeight), Vec3(0, y, stepHeight),
        ]
        for corner in 1..<(outline.count - 1) {
            builder.triangle(outline[0], outline[corner], outline[corner + 1], outward: outward)
        }
    }

    /// The base's top face around the boss: a band of quads from the boss's circle out
    /// to a square ring, then fans from the face's four corners to the ring. Only the
    /// corners lie on the face's edges, so the neighbouring faces join it exactly.
    static func addSurround(to builder: inout MeshBuilder) {
        let circle = (0..<segments).map(circlePoint)
        let ring = (0..<segments).map(ringPoint)
        for index in 0..<segments {
            let next = (index + 1) % segments
            builder.quad([circle[index], circle[next], ring[next], ring[index]], outward: upward)
        }
        let quarter = segments / 4
        for side in 0..<4 {
            // Ring points at 45°, 135°, 225° and 315° sit on the diagonals, pointing at
            // the face's corners.
            let start = segments / 8 + side * quarter
            let corner = outerCorner(start)
            for step in 0..<quarter {
                let here = (start + step) % segments
                builder.triangle(corner, ring[here], ring[(here + 1) % segments], outward: upward)
            }
            let end = (start + quarter) % segments
            builder.triangle(corner, outerCorner(end), ring[end], outward: upward)
        }
    }

    /// The boss's round side and flat top.
    static func addBoss(to builder: inout MeshBuilder) {
        let lift = Vec3(0, 0, bossTop - baseHeight)
        let topCentre = bossCentre + lift
        for index in 0..<segments {
            let next = (index + 1) % segments
            let bottom = circlePoint(index)
            let bottomNext = circlePoint(next)
            let middle = (bottom + bottomNext) / 2 - bossCentre
            builder.quad([bottom, bottomNext, bottomNext + lift, bottom + lift], outward: middle)
            builder.triangle(topCentre, bottom + lift, bottomNext + lift, outward: upward)
        }
    }

    private static func angle(_ index: Int) -> Double {
        2 * Double.pi * Double(index) / Double(segments)
    }

    private static func circlePoint(_ index: Int) -> Vec3 {
        bossCentre + Vec3(cos(angle(index)), sin(angle(index)), 0) * bossRadius
    }

    /// The point on a square around the boss in the direction of `circlePoint(index)`.
    private static func ringPoint(_ index: Int) -> Vec3 {
        let direction = Vec3(cos(angle(index)), sin(angle(index)), 0)
        let reach = ringHalfWidth / max(abs(direction.x), abs(direction.y))
        return bossCentre + direction * reach
    }

    /// The corner of the base's top face in the direction of ring point `index`,
    /// which must be one of the four diagonal points.
    private static func outerCorner(_ index: Int) -> Vec3 {
        let direction = ringPoint(index) - bossCentre
        let x = direction.x > 0 ? length : stepEnd
        let y = direction.y > 0 ? depth : 0
        return Vec3(x, y, baseHeight)
    }
}

/// Collects triangles for a mesh, merging corners at the same position into one
/// vertex so that neighbouring faces join without gaps.
struct MeshBuilder {
    private var vertices: [Vec3] = []
    private var triangles: [Triangle] = []
    private var lookup: [PositionKey: Int] = [:]

    var mesh: Mesh { Mesh(unchecked: vertices, triangles: triangles) }

    /// Adds a triangle, turning it if needed so it faces `outward`. Working the
    /// winding out from the direction avoids a whole class of hand-ordering mistakes.
    mutating func triangle(_ first: Vec3, _ second: Vec3, _ third: Vec3, outward: Vec3) {
        let facing = (second - first).cross(third - first).dot(outward)
        let one = vertex(first)
        let two = vertex(second)
        let three = vertex(third)
        triangles.append(facing >= 0 ? Triangle(one, two, three) : Triangle(one, three, two))
    }

    /// Adds a four-cornered face, corners in order around it, as two triangles.
    mutating func quad(_ corners: [Vec3], outward: Vec3) {
        triangle(corners[0], corners[1], corners[2], outward: outward)
        triangle(corners[0], corners[2], corners[3], outward: outward)
    }

    private mutating func vertex(_ point: Vec3) -> Int {
        let key = PositionKey(point)
        if let existing = lookup[key] { return existing }
        vertices.append(point)
        lookup[key] = vertices.count - 1
        return vertices.count - 1
    }
}

/// A position rounded to 0.1 micrometre (in millimetre units), so that two
/// calculations of the same corner that differ only by rounding still match.
private struct PositionKey: Hashable {
    let x: Int64
    let y: Int64
    let z: Int64

    init(_ point: Vec3) {
        x = Int64((point.x * 10_000).rounded())
        y = Int64((point.y * 10_000).rounded())
        z = Int64((point.z * 10_000).rounded())
    }
}
