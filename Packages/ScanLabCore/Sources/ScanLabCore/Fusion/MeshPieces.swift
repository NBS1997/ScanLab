import Foundation

/// Finds the separate pieces of a mesh and drops the small ones (DF-4).
///
/// Two triangles belong to the same piece when they share a corner. Pieces are found
/// with a "union-find": every corner starts as its own group, each triangle merges the
/// groups of its three corners, and at the end every corner knows its group's leader.
enum MeshPieces {
    static func droppingSmallPieces(of mesh: Mesh, smallestFaces: Int) -> FusedMesh {
        guard smallestFaces > 1, !mesh.isEmpty else {
            return FusedMesh(mesh: mesh, piecesDropped: 0, facesDropped: 0)
        }
        var leaders = Array(mesh.vertices.indices)
        func leader(of corner: Int) -> Int {
            var current = corner
            while leaders[current] != current {
                // Point each visited corner at its grandparent, so later searches are short.
                leaders[current] = leaders[leaders[current]]
                current = leaders[current]
            }
            return current
        }
        for triangle in mesh.triangles {
            let first = leader(of: triangle.a)
            leaders[leader(of: triangle.b)] = first
            leaders[leader(of: triangle.c)] = first
        }

        var facesInPiece: [Int: Int] = [:]
        let pieceOfFace = mesh.triangles.map { leader(of: $0.a) }
        for piece in pieceOfFace {
            facesInPiece[piece, default: 0] += 1
        }
        let kept = mesh.triangles.indices.filter { facesInPiece[pieceOfFace[$0], default: 0] >= smallestFaces }
        let dropped = facesInPiece.values.filter { $0 < smallestFaces }

        // Keep only the corners the remaining triangles use, numbered afresh.
        var newNumber = [Int](repeating: -1, count: mesh.vertexCount)
        var vertices: [Vec3] = []
        var triangles: [Triangle] = []
        triangles.reserveCapacity(kept.count)
        func renumber(_ corner: Int) -> Int {
            if newNumber[corner] < 0 {
                newNumber[corner] = vertices.count
                vertices.append(mesh.vertices[corner])
            }
            return newNumber[corner]
        }
        for face in kept {
            let triangle = mesh.triangles[face]
            triangles.append(Triangle(renumber(triangle.a), renumber(triangle.b), renumber(triangle.c)))
        }
        return FusedMesh(
            mesh: Mesh(unchecked: vertices, triangles: triangles), piecesDropped: dropped.count,
            facesDropped: dropped.reduce(0, +))
    }
}
