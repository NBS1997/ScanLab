import Foundation

/// The file types a mesh can be exported as (FR-7.1).
public enum MeshFormat: String, CaseIterable, Sendable, Identifiable {
    case stl
    case obj

    public var id: String { rawValue }

    public var fileExtension: String { rawValue }

    public var displayName: String { rawValue.uppercased() }
}

/// The length unit used by numbers in a file.
public enum FileUnit: Sendable {
    case metres
    case millimetres

    public var metresPerUnit: Double {
        switch self {
        case .metres: 1
        case .millimetres: 1 / Units.millimetresPerMetre
        }
    }
}

/// Why a mesh file could not be written or read.
public enum MeshFileError: Error, Equatable, Sendable {
    /// The storage is full. Nothing was written (NFR-9).
    case noSpace
    case writeFailed(String)
    case readFailed(String)
    /// Line `line` of an OBJ file could not be understood.
    case malformed(line: Int, reason: String)
    /// More faces than the file format can hold.
    case tooLarge(faces: Int)
}

extension MeshFileError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noSpace:
            let nextStep = "Free up some space, then try again."
            return "There is not enough free space to write the file, so nothing was saved. \(nextStep)"
        case .writeFailed(let reason):
            return "The file could not be written: \(reason). Nothing was saved. Try again."
        case .readFailed(let reason):
            return "The file could not be read: \(reason)."
        case .malformed(let line, let reason):
            return "Line \(line) of the file could not be read: \(reason)."
        case .tooLarge(let faces):
            return "The model has \(faces) faces, more than the file type can hold. Choose less detail."
        }
    }
}

/// Writes meshes as binary STL or OBJ (ADR-013).
///
/// Meshes are in metres inside the app; **files are written in millimetres**, the
/// unit Fusion, Blender and slicers assume for STL and OBJ when nothing says
/// otherwise (FR-7.2). Every position is multiplied by 1,000 on the way out.
public enum MeshFiles {
    /// The 80-byte header of our STL files. It must not start with "solid", or some
    /// programs mistake the file for the text form of STL.
    static let stlHeader = "ScanLab binary STL, units: millimetres"

    /// A binary STL file is an 80-byte header, a 4-byte face count, then 50 bytes per
    /// face: a normal and three corners (twelve 4-byte numbers) and a 2-byte spare.
    public static func stlByteCount(faceCount: Int) -> Int {
        84 + 50 * faceCount
    }

    public static func data(for mesh: Mesh, as format: MeshFormat) throws -> Data {
        switch format {
        case .stl: try stlData(for: mesh)
        case .obj: Data(objText(for: mesh).utf8)
        }
    }

    /// Binary STL in millimetres. All numbers are little-endian, as the format
    /// requires.
    public static func stlData(for mesh: Mesh) throws -> Data {
        guard mesh.faceCount <= Int(UInt32.max) else { throw MeshFileError.tooLarge(faces: mesh.faceCount) }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(stlByteCount(faceCount: mesh.faceCount))
        let header = Array(stlHeader.utf8)
        bytes += header
        // Pad the header to 80 bytes with spaces.
        bytes += [UInt8](repeating: 0x20, count: 80 - header.count)
        append(UInt32(mesh.faceCount), to: &bytes)
        let scale = Units.millimetresPerMetre
        for (index, triangle) in mesh.triangles.enumerated() {
            append(mesh.faceNormal(index), to: &bytes)
            append(mesh.vertices[triangle.a] * scale, to: &bytes)
            append(mesh.vertices[triangle.b] * scale, to: &bytes)
            append(mesh.vertices[triangle.c] * scale, to: &bytes)
            bytes += [0, 0]
        }
        return Data(bytes)
    }

    /// OBJ text in millimetres: one `v x y z` line per vertex, then one `f a b c` line
    /// per face (OBJ counts vertices from 1).
    public static func objText(for mesh: Mesh) -> String {
        var text = "# ScanLab OBJ, units: millimetres\n"
        text += "# \(mesh.vertexCount) vertices, \(mesh.faceCount) faces\n"
        text.reserveCapacity(mesh.vertexCount * 32 + mesh.faceCount * 24)
        let scale = Units.millimetresPerMetre
        for vertex in mesh.vertices {
            let point = vertex * scale
            text += "v \(formatNumber(point.x)) \(formatNumber(point.y)) \(formatNumber(point.z))\n"
        }
        for triangle in mesh.triangles {
            text += "f \(triangle.a + 1) \(triangle.b + 1) \(triangle.c + 1)\n"
        }
        return text
    }

    /// Writes the mesh. The file appears complete or not at all: it is written to a
    /// temporary file beside the destination and then moved into place.
    public static func write(_ mesh: Mesh, as format: MeshFormat, to url: URL) throws {
        try write(data(for: mesh, as: format), to: url, availableCapacity: nil)
    }

    /// Writes prepared file contents. When `availableCapacity` (free bytes on the
    /// destination's storage) is known and too small, fails with `.noSpace` before
    /// writing anything.
    public static func write(_ data: Data, to url: URL, availableCapacity: Int64?) throws {
        // Leave room for the temporary copy that the safe write makes, and some spare.
        let needed = Int64(data.count) + 1_000_000
        if let availableCapacity, availableCapacity < needed {
            throw MeshFileError.noSpace
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw classify(error)
        }
    }

    /// Turns a system error into a `MeshFileError`, recognising "storage full" in its
    /// several forms.
    public static func classify(_ error: any Error) -> MeshFileError {
        if let fileError = error as? MeshFileError { return fileError }
        let nsError = error as NSError
        return isOutOfSpace(nsError) ? .noSpace : .writeFailed(nsError.localizedDescription)
    }

    private static func isOutOfSpace(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError { return true }
        if error.domain == NSPOSIXErrorDomain && (error.code == Int(ENOSPC) || error.code == Int(EDQUOT)) {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isOutOfSpace(underlying)
        }
        return false
    }

    /// A number with at most four decimal places (0.1 micrometre in millimetres),
    /// without trailing zeros or exponents, and always with "." as the decimal point
    /// whatever the phone's region. For example 60, 12.5, -0.0001.
    static func formatNumber(_ value: Double) -> String {
        let scaled = (value * 10_000).rounded()
        guard scaled.isFinite, abs(scaled) < 9e15 else { return "\(value)" }
        let units = Int64(scaled)
        let sign = units < 0 ? "-" : ""
        let whole = units.magnitude / 10_000
        var fraction = units.magnitude % 10_000
        guard fraction > 0 else { return "\(sign)\(whole)" }
        var digits = 4
        while fraction % 10 == 0 {
            fraction /= 10
            digits -= 1
        }
        let fractionText = String(fraction)
        let padding = String(repeating: "0", count: digits - fractionText.count)
        return "\(sign)\(whole).\(padding)\(fractionText)"
    }

    private static func append(_ value: UInt32, to bytes: inout [UInt8]) {
        withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }

    private static func append(_ vector: Vec3, to bytes: inout [UInt8]) {
        append(Float(vector.x).bitPattern, to: &bytes)
        append(Float(vector.y).bitPattern, to: &bytes)
        append(Float(vector.z).bitPattern, to: &bytes)
    }
}
