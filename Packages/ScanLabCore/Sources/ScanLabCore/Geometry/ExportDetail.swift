import Foundation

/// How much detail an export keeps (requirement FR-7.3).
public enum ExportDetail: String, CaseIterable, Sendable, Identifiable {
    /// Every face the model has.
    case full
    /// At most 10,000 faces: the most Fusion reliably turns into a solid (PC2).
    case fusionFriendly
    /// At most 5,000 faces, for quick previews and small files.
    case light

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .full: "Full"
        case .fusionFriendly: "Fusion-friendly"
        case .light: "Light"
        }
    }

    /// One line saying what the level is for.
    public var summary: String {
        switch self {
        case .full: "Every face. For Blender and slicers."
        case .fusionFriendly: "Up to 10,000 faces, so Fusion can turn it into a solid."
        case .light: "Up to 5,000 faces. Smallest file."
        }
    }

    /// The most faces this level allows, or `nil` for no limit.
    public var faceLimit: Int? {
        switch self {
        case .full: nil
        case .fusionFriendly: 10_000
        case .light: 5_000
        }
    }

    /// The face count to aim for with this mesh: its own count, or the limit if that
    /// is smaller.
    public func targetFaces(for mesh: Mesh) -> Int {
        guard let faceLimit else { return mesh.faceCount }
        return min(faceLimit, mesh.faceCount)
    }

    /// The mesh as it will be exported at this level.
    public func prepare(_ mesh: Mesh) throws -> Mesh {
        try MeshSimplifier.simplify(mesh, targetFaces: targetFaces(for: mesh))
    }
}

/// Names for exported files.
public enum ExportNaming {
    /// For example "Sample stepped block (Fusion-friendly).stl". Characters that
    /// folders on the phone or on Windows do not allow are replaced with "-".
    public static func fileName(for name: String, detail: ExportDetail, format: MeshFormat) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var cleaned = String.UnicodeScalarView()
        for scalar in name.unicodeScalars {
            cleaned.append(forbidden.contains(scalar) ? "-" : scalar)
        }
        let trimmed = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "ScanLab model" : trimmed
        return "\(base) (\(detail.displayName)).\(format.fileExtension)"
    }
}
