import Foundation

extension MeshFiles {
    /// Reads a binary STL file whose numbers are in `unit`, giving a mesh in metres.
    ///
    /// STL repeats every corner for each face that uses it; identical corners are
    /// merged here, so the mesh knows which faces touch. The file's stored face
    /// normals are ignored: each face's direction comes from the order of its corners,
    /// as everywhere else in the app.
    ///
    /// Only the binary form is read (the reference-object script writes binary). A file
    /// whose length does not match its face count, such as the text form of STL, is
    /// refused rather than misread.
    public static func parseBinarySTL(_ data: Data, unit: FileUnit) throws -> Mesh {
        guard data.count >= 84 else { throw MeshFileError.readFailed("the file is too short to be an STL file") }
        let bytes = [UInt8](data)
        let faceCount = Int(readUInt32(bytes, at: 80))
        guard data.count >= stlByteCount(faceCount: faceCount) else {
            throw MeshFileError.readFailed("the file is shorter than its \(faceCount) faces need, or is text STL")
        }
        var vertices: [Vec3] = []
        var triangles: [Triangle] = []
        var lookup: [CornerKey: Int] = [:]
        vertices.reserveCapacity(faceCount / 2 + 3)
        triangles.reserveCapacity(faceCount)
        let scale = unit.metresPerUnit
        for face in 0..<faceCount {
            // Skip the 12-byte normal; the three corners follow.
            let start = 84 + face * 50 + 12
            var corners: [Int] = []
            for corner in 0..<3 {
                let key = CornerKey(bytes: bytes, at: start + corner * 12)
                if let existing = lookup[key] {
                    corners.append(existing)
                    continue
                }
                let position = key.position * scale
                guard position.isFinite else {
                    throw MeshFileError.readFailed("face \(face + 1) has a corner that is not a number")
                }
                lookup[key] = vertices.count
                corners.append(vertices.count)
                vertices.append(position)
            }
            triangles.append(Triangle(corners[0], corners[1], corners[2]))
        }
        return Mesh(unchecked: vertices, triangles: triangles)
    }

    fileprivate static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        // Little-endian: the first byte is the smallest part.
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}

/// A corner as the file stores it (three 4-byte numbers), used to find repeats. Two
/// corners merge only when their stored bits are identical.
private struct CornerKey: Hashable {
    var x: UInt32
    var y: UInt32
    var z: UInt32

    init(bytes: [UInt8], at offset: Int) {
        x = MeshFiles.readUInt32(bytes, at: offset)
        y = MeshFiles.readUInt32(bytes, at: offset + 4)
        z = MeshFiles.readUInt32(bytes, at: offset + 8)
    }

    var position: Vec3 {
        Vec3(Double(Float(bitPattern: x)), Double(Float(bitPattern: y)), Double(Float(bitPattern: z)))
    }
}
