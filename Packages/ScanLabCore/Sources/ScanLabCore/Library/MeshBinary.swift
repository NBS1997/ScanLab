import Foundation

/// The file a scan's model is kept in on the phone (`mesh.slmesh`).
///
/// Why our own binary layout rather than OBJ or STL (decision recorded in the U05
/// functional design):
/// - **Exact.** Positions are stored as the same 8-byte numbers the app works with, so
///   a saved scan reads back bit for bit. OBJ keeps four decimals and STL keeps 4-byte
///   numbers, so both would change a scan a little every time it was saved.
/// - **Compact and fast.** 24 bytes per vertex and 12 per face: a 200,000-face scan is
///   about 4.8 MB and reads in one pass with no text to parse. OBJ would be two to
///   three times larger and much slower to read.
/// - **Checkable.** The header states the counts, so a cut-short file is recognised
///   and reported as damaged instead of loading as a broken model.
/// Exports to other programs still use STL or OBJ (`MeshFiles`).
///
/// Layout, every number little-endian:
///
/// | Bytes | Contents |
/// |---|---|
/// | 8 | the text `SLMESH01` |
/// | 4 | vertex count (unsigned) |
/// | 4 | face count (unsigned) |
/// | 24 × vertices | x, y, z in metres, 8-byte floating point |
/// | 12 × faces | the three vertex numbers, 4-byte unsigned |
public enum MeshBinary {
    /// The first eight bytes of every file: a name and a layout version.
    static let magic = Array("SLMESH01".utf8)
    static let headerSize = 16

    /// The exact file size for a mesh with these counts.
    public static func byteCount(vertices: Int, faces: Int) -> Int {
        headerSize + 24 * vertices + 12 * faces
    }

    public static func encode(_ mesh: Mesh) throws -> Data {
        guard mesh.vertexCount <= Int(UInt32.max), mesh.faceCount <= Int(UInt32.max) else {
            throw StoreError.writeFailed("the model is too large to store")
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(byteCount(vertices: mesh.vertexCount, faces: mesh.faceCount))
        bytes += magic
        append(UInt32(mesh.vertexCount), to: &bytes)
        append(UInt32(mesh.faceCount), to: &bytes)
        for vertex in mesh.vertices {
            append(vertex.x.bitPattern, to: &bytes)
            append(vertex.y.bitPattern, to: &bytes)
            append(vertex.z.bitPattern, to: &bytes)
        }
        for triangle in mesh.triangles {
            append(UInt32(triangle.a), to: &bytes)
            append(UInt32(triangle.b), to: &bytes)
            append(UInt32(triangle.c), to: &bytes)
        }
        return Data(bytes)
    }

    /// Reads a model file. A file of the wrong kind, the wrong length, or with faces
    /// that point at missing vertices is reported as `StoreError.corrupt`.
    public static func decode(_ data: Data) throws -> Mesh {
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) throws -> Mesh in
            guard raw.count >= headerSize, Array(raw.prefix(magic.count)) == magic else {
                throw StoreError.corrupt("the model file is not a ScanLab model")
            }
            let vertexCount = Int(readUInt32(raw, at: 8))
            let faceCount = Int(readUInt32(raw, at: 12))
            guard raw.count == byteCount(vertices: vertexCount, faces: faceCount) else {
                throw StoreError.corrupt("the model file is incomplete")
            }
            var vertices: [Vec3] = []
            vertices.reserveCapacity(vertexCount)
            var offset = headerSize
            for _ in 0..<vertexCount {
                let x = Double(bitPattern: readUInt64(raw, at: offset))
                let y = Double(bitPattern: readUInt64(raw, at: offset + 8))
                let z = Double(bitPattern: readUInt64(raw, at: offset + 16))
                vertices.append(Vec3(x, y, z))
                offset += 24
            }
            var triangles: [Triangle] = []
            triangles.reserveCapacity(faceCount)
            for _ in 0..<faceCount {
                let first = Int(readUInt32(raw, at: offset))
                let second = Int(readUInt32(raw, at: offset + 4))
                let third = Int(readUInt32(raw, at: offset + 8))
                triangles.append(Triangle(first, second, third))
                offset += 12
            }
            do {
                return try Mesh(vertices: vertices, triangles: triangles)
            } catch {
                throw StoreError.corrupt("the model file refers to points that are not there")
            }
        }
    }

    private static func append(_ value: UInt32, to bytes: inout [UInt8]) {
        withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }

    private static func append(_ value: UInt64, to bytes: inout [UInt8]) {
        withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }

    /// `loadUnaligned` reads a number from any byte position; the file's numbers are
    /// not lined up on 4- or 8-byte boundaries in memory.
    private static func readUInt32(_ raw: UnsafeRawBufferPointer, at offset: Int) -> UInt32 {
        UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    private static func readUInt64(_ raw: UnsafeRawBufferPointer, at offset: Int) -> UInt64 {
        UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }
}
