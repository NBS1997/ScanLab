import Foundation

extension MeshFiles {
    /// Reads the shape from an OBJ file, such as the models the phone builds from
    /// photographs (unit U08). `unit` says what the file's numbers mean; the mesh
    /// that comes back is in metres.
    public static func read(from url: URL, unit: FileUnit = .metres) throws -> Mesh {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MeshFileError.readFailed(error.localizedDescription)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw MeshFileError.readFailed("the file is not text")
        }
        return try parseOBJ(text, unit: unit)
    }

    /// Reads OBJ text. Only positions (`v`) and faces (`f`) matter here; texture
    /// coordinates, normals, groups and materials are skipped. Faces with more than
    /// three corners are split into triangles fanning out from the first corner.
    public static func parseOBJ(_ text: String, unit: FileUnit = .metres) throws -> Mesh {
        var parser = OBJParser(scale: unit.metresPerUnit)
        var number = 0
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            number += 1
            try parser.consume(line, number: number)
        }
        return Mesh(unchecked: parser.vertices, triangles: parser.triangles)
    }
}

/// Reads an OBJ file one line at a time.
struct OBJParser {
    let scale: Double
    private(set) var vertices: [Vec3] = []
    private(set) var triangles: [Triangle] = []

    init(scale: Double) {
        self.scale = scale
    }

    mutating func consume(_ line: Substring, number: Int) throws {
        // Anything after "#" is a comment.
        let content = line.prefix { $0 != "#" }
        let tokens = content.split { $0 == " " || $0 == "\t" }
        guard let keyword = tokens.first else { return }
        switch keyword {
        case "v":
            vertices.append(try vertex(tokens, number: number))
        case "f":
            try addFace(tokens.dropFirst(), number: number)
        default:
            return
        }
    }

    private func vertex(_ tokens: [Substring], number: Int) throws -> Vec3 {
        guard tokens.count >= 4 else {
            throw MeshFileError.malformed(line: number, reason: "a vertex needs three numbers")
        }
        let parts = tokens[1...3].compactMap { Double($0) }
        guard parts.count == 3 else {
            throw MeshFileError.malformed(line: number, reason: "a vertex position is not a number")
        }
        let point = Vec3(parts[0], parts[1], parts[2]) * scale
        guard point.isFinite else {
            throw MeshFileError.malformed(line: number, reason: "a vertex position is too large")
        }
        return point
    }

    private mutating func addFace(_ corners: ArraySlice<Substring>, number: Int) throws {
        guard corners.count >= 3 else {
            throw MeshFileError.malformed(line: number, reason: "a face needs at least three corners")
        }
        let indices = try corners.map { try index(of: $0, number: number) }
        for corner in 1..<(indices.count - 1) {
            triangles.append(Triangle(indices[0], indices[corner], indices[corner + 1]))
        }
    }

    /// A corner is written `v`, `v/t`, `v//n` or `v/t/n`; only `v`, the vertex
    /// number, matters. Numbers count from 1; negative numbers count back from the
    /// latest vertex.
    private func index(of corner: Substring, number: Int) throws -> Int {
        let field = corner.prefix { $0 != "/" }
        guard let written = Int(field), written != 0 else {
            throw MeshFileError.malformed(line: number, reason: "\"\(corner)\" is not a vertex number")
        }
        let index = written > 0 ? written - 1 : vertices.count + written
        guard index >= 0 && index < vertices.count else {
            throw MeshFileError.malformed(line: number, reason: "vertex \(written) does not exist")
        }
        return index
    }
}
