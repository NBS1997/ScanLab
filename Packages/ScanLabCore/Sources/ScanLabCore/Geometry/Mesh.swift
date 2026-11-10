import Foundation

/// One face of a mesh: three positions in the mesh's vertex list. Looking at the
/// outside of the surface, the corners run anticlockwise.
public struct Triangle: Hashable, Sendable {
    public var a: Int
    public var b: Int
    public var c: Int

    public init(_ a: Int, _ b: Int, _ c: Int) {
        self.a = a
        self.b = b
        self.c = c
    }

    public var indices: [Int] { [a, b, c] }

    /// The same face seen from the other side.
    public var flipped: Triangle { Triangle(a, c, b) }
}

/// Why a mesh could not be built.
public enum MeshError: Error, Equatable, Sendable {
    /// Triangle number `triangle` refers to a vertex that does not exist.
    case indexOutOfRange(triangle: Int, index: Int)
    /// Vertex number `vertex` is infinite or not a number.
    case nonFiniteVertex(vertex: Int)
}

/// A surface made of triangles, with positions in metres (ADR-013). Exports convert
/// to millimetres when they write the file.
public struct Mesh: Equatable, Sendable {
    public private(set) var vertices: [Vec3]
    public private(set) var triangles: [Triangle]

    /// Builds a mesh after checking that every triangle refers to a real vertex and
    /// that every position is a finite number.
    public init(vertices: [Vec3], triangles: [Triangle]) throws {
        for (index, vertex) in vertices.enumerated() where !vertex.isFinite {
            throw MeshError.nonFiniteVertex(vertex: index)
        }
        let count = vertices.count
        for (number, triangle) in triangles.enumerated() {
            for index in triangle.indices where index < 0 || index >= count {
                throw MeshError.indexOutOfRange(triangle: number, index: index)
            }
        }
        self.init(unchecked: vertices, triangles: triangles)
    }

    /// For code in this package that has already made sure the indices are valid.
    init(unchecked vertices: [Vec3], triangles: [Triangle]) {
        self.vertices = vertices
        self.triangles = triangles
    }

    public static let empty = Mesh(unchecked: [], triangles: [])

    public var vertexCount: Int { vertices.count }

    public var faceCount: Int { triangles.count }

    public var isEmpty: Bool { triangles.isEmpty }

    /// The overall size, counting only vertices that some face uses (the same points
    /// an STL file would contain). `nil` when the mesh has no faces.
    public var boundingBox: Box? {
        var used = [Bool](repeating: false, count: vertices.count)
        for triangle in triangles {
            used[triangle.a] = true
            used[triangle.b] = true
            used[triangle.c] = true
        }
        return Box(enclosing: vertices.indices.lazy.filter { used[$0] }.map { vertices[$0] })
    }

    /// The face's outward direction, length 1; zero for a face with no area.
    public func faceNormal(_ index: Int) -> Vec3 {
        areaVector(triangles[index]).normalised
    }

    /// Total area of all faces, in square metres.
    public var surfaceArea: Double {
        triangles.reduce(0) { $0 + areaVector($1).length / 2 }
    }

    /// The enclosed volume in cubic metres, for a closed mesh whose faces point
    /// outwards. Each face forms a pyramid with the origin; adding up their signed
    /// volumes leaves exactly the inside (the divergence theorem). Negative means the
    /// faces point inwards.
    public var volume: Double {
        let sixfold = triangles.reduce(0.0) { total, triangle in
            let first = vertices[triangle.a]
            return total + first.dot(vertices[triangle.b].cross(vertices[triangle.c]))
        }
        return sixfold / 6
    }

    /// How many edges belong to only one face. Zero means the surface is closed
    /// (watertight), which Fusion needs before it can turn a mesh into a solid.
    public var openEdgeCount: Int {
        var keys: [UInt64] = []
        keys.reserveCapacity(triangles.count * 3)
        for triangle in triangles {
            keys.append(EdgeKey(triangle.a, triangle.b).value)
            keys.append(EdgeKey(triangle.b, triangle.c).value)
            keys.append(EdgeKey(triangle.c, triangle.a).value)
        }
        keys.sort()
        var open = 0
        var start = 0
        while start < keys.count {
            var end = start + 1
            while end < keys.count && keys[end] == keys[start] { end += 1 }
            if end - start == 1 { open += 1 }
            start = end
        }
        return open
    }

    /// Every vertex moved by `transform`. A mirroring transform also flips each face
    /// so the surface still faces outwards.
    public func transformed(by transform: Transform) -> Mesh {
        let moved = vertices.map { transform.apply(to: $0) }
        let faces = transform.determinant < 0 ? triangles.map(\.flipped) : triangles
        return Mesh(unchecked: moved, triangles: faces)
    }

    /// Resized about the origin, for example by 1,000 to turn metres into millimetres.
    public func scaled(by factor: Double) -> Mesh {
        transformed(by: .scaling(by: factor))
    }

    /// The same surface without vertices that no face uses. Vertices keep their order.
    public func compacted() -> Mesh {
        var newIndex = [Int](repeating: -1, count: vertices.count)
        for triangle in triangles {
            newIndex[triangle.a] = 0
            newIndex[triangle.b] = 0
            newIndex[triangle.c] = 0
        }
        var kept: [Vec3] = []
        for index in vertices.indices where newIndex[index] == 0 {
            newIndex[index] = kept.count
            kept.append(vertices[index])
        }
        let faces = triangles.map { Triangle(newIndex[$0.a], newIndex[$0.b], newIndex[$0.c]) }
        return Mesh(unchecked: kept, triangles: faces)
    }

    /// Twice the face's area, pointing outwards.
    func areaVector(_ triangle: Triangle) -> Vec3 {
        let first = vertices[triangle.a]
        return (vertices[triangle.b] - first).cross(vertices[triangle.c] - first)
    }
}

/// An edge between two vertices regardless of direction, packed into one number so
/// that lists of edges can be sorted and compared quickly.
struct EdgeKey: Hashable, Comparable {
    let value: UInt64

    init(_ first: Int, _ second: Int) {
        let low = UInt64(Swift.min(first, second))
        let high = UInt64(Swift.max(first, second))
        value = (low << 32) | high
    }

    var low: Int { Int(value >> 32) }

    var high: Int { Int(value & 0xFFFF_FFFF) }

    static func < (lhs: EdgeKey, rhs: EdgeKey) -> Bool {
        lhs.value < rhs.value
    }
}
