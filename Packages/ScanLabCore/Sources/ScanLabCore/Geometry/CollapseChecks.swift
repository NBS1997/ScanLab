import Foundation

/// The safety checks run before each merge. A merge that fails any of them is
/// skipped; the edge may come back into the queue later if its surroundings change.
extension EdgeCollapser {
    /// Whether merging `remove` into `keep` at `position` keeps the surface sound.
    func isAcceptable(keep: Int, remove: Int, at position: Vec3) -> Bool {
        let keepFaces = faceList(of: keep)
        let removeFaces = faceList(of: remove)
        guard let opposite = oppositeVertices(keepFaces, keep: keep, remove: remove) else { return false }
        guard sharesOnly(opposite, keep: keep, remove: remove) else { return false }
        // The faces that survive the merge, each with one corner moving.
        let keepMoved = keepFaces.filter { !faces[$0].contains(remove) }
        let moved = keepMoved + removeFaces.filter { !faces[$0].contains(keep) }
        guard !createsDuplicate(moved, keep: keep, remove: remove) else { return false }
        for face in moved {
            let mover = faces[face].contains(keep) ? keep : remove
            guard keepsFacing(faces[face], moving: mover, to: position) else { return false }
        }
        return true
    }

    /// The third corners of the faces on the edge, or `nil` when the edge does not
    /// exist or is shared by more than two faces (a "non-manifold" edge, where
    /// merging would join surfaces that should stay apart).
    private func oppositeVertices(_ keepFaces: [Int], keep: Int, remove: Int) -> [Int]? {
        var opposite: [Int] = []
        for face in keepFaces where faces[face].contains(remove) {
            let third = faces[face].indices.first { $0 != keep && $0 != remove }
            guard let third, !opposite.contains(third) else { return nil }
            opposite.append(third)
        }
        return opposite.isEmpty || opposite.count > 2 ? nil : opposite
    }

    /// The "link condition": the two ends may only have in common the corners of the
    /// faces between them. If they share another neighbour, merging them would pinch
    /// the surface into a point or a thread. Also refuses a merge that would join the
    /// vertex to too many others (see `maximumValence`).
    private func sharesOnly(_ opposite: [Int], keep: Int, remove: Int) -> Bool {
        let keepNeighbours = neighbours(of: keep)
        let removeNeighbours = neighbours(of: remove)
        let common = keepNeighbours.filter { removeNeighbours.contains($0) }
        guard common.count == opposite.count else { return false }
        // Joined after the merge: both lists, less each other, less the shared ones.
        let valence = keepNeighbours.count + removeNeighbours.count - 2 - common.count
        return valence <= Self.maximumValence
    }

    /// Whether two faces would end up with the same three corners, as happens when a
    /// closed shape is already as simple as it can be (for example a tetrahedron).
    private func createsDuplicate(_ moved: [Int], keep: Int, remove: Int) -> Bool {
        var seen = Set<[Int]>()
        for face in moved {
            var corners = faces[face]
            corners.replace(remove, with: keep)
            let key = corners.indices.sorted()
            if seen.contains(key) { return true }
            seen.insert(key)
        }
        return false
    }

    /// Whether the face still points roughly the same way after its corner `vertex`
    /// moves to `point`. A face that would flip over or shrink to nothing fails.
    private func keepsFacing(_ face: Triangle, moving vertex: Int, to point: Vec3) -> Bool {
        let before = areaVector(face)
        let beforeLength = before.length
        // A face that already had no area cannot get worse.
        guard beforeLength > 0 else { return true }
        let first = face.a == vertex ? point : positions[face.a]
        let second = face.b == vertex ? point : positions[face.b]
        let third = face.c == vertex ? point : positions[face.c]
        let after = (second - first).cross(third - first)
        return before.dot(after) > Self.minimumNormalAgreement * beforeLength * after.length
    }
}
