import Foundation

/// How big a feature is, as the feature table groups them (FR-9.6). The limits come
/// from the table itself: by default small is up to 5 mm, medium up to 30 mm, and
/// large is anything bigger.
public enum SizeClass: String, Codable, CaseIterable, Comparable, Sendable {
    case small
    case medium
    case large

    public var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    private var rank: Int {
        switch self {
        case .small: 0
        case .medium: 1
        case .large: 2
        }
    }

    public static func < (lhs: SizeClass, rhs: SizeClass) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// What sort of feature it is, as in the measurement sheet. A kind added to the table
/// by a later script reads as `.other` rather than failing.
public enum FeatureKind: String, Codable, CaseIterable, Sendable {
    case length
    case step
    case hole
    case boss
    case angle
    case curve
    case other

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        self = FeatureKind(rawValue: text) ?? .other
    }

    /// The group heading used on the measurement sheet.
    public var groupTitle: String {
        switch self {
        case .length: "Lengths between faces"
        case .step: "Steps and heights"
        case .hole: "Holes"
        case .boss: "Round posts (bosses)"
        case .angle: "Angles between faces"
        case .curve: "Curved surfaces"
        case .other: "Other features"
        }
    }
}

/// The unit a feature's value is written in.
public enum FeatureUnit: String, Codable, Sendable {
    case millimetres = "mm"
    case degrees = "deg"

    /// As shown beside a number: "mm" or "°".
    public var symbol: String {
        switch self {
        case .millimetres: "mm"
        case .degrees: "°"
        }
    }

    /// As read by the screen reader.
    public var spokenName: String {
        switch self {
        case .millimetres: "millimetres"
        case .degrees: "degrees"
        }
    }
}

/// One measurable feature of the reference object, from `feature-table.json`.
public struct ReferenceFeature: Identifiable, Equatable, Sendable {
    /// For example "L1" or "H3".
    public var id: String
    public var kind: FeatureKind
    /// What the feature is, for example "Diameter of the 5 mm round through hole".
    public var summary: String
    /// The value in the design, in `unit`.
    public var designValue: Double
    public var unit: FeatureUnit
    /// The feature's size in millimetres, which decides its size class.
    public var sizeMillimetres: Double
    public var sizeClass: SizeClass
    /// How to measure it with calipers, from the measurement sheet.
    public var howToMeasure: String
    /// The box around the feature in object coordinates, in **millimetres**.
    public var region: Box

    /// - Parameter sizeMillimetres: the size deciding the class; the design value when
    ///   `nil`.
    public init(
        id: String,
        kind: FeatureKind,
        summary: String = "",
        designValue: Double,
        unit: FeatureUnit = .millimetres,
        sizeMillimetres: Double? = nil,
        sizeClass: SizeClass,
        howToMeasure: String = "",
        region: Box
    ) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.designValue = designValue
        self.unit = unit
        self.sizeMillimetres = sizeMillimetres ?? designValue
        self.sizeClass = sizeClass
        self.howToMeasure = howToMeasure
        self.region = region
    }
}

extension ReferenceFeature: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case summary = "description"
        case designValue
        case unit
        case sizeMillimetres = "sizeMm"
        case sizeClass
        case howToMeasure = "measure"
        case region
    }

    private struct RegionCorners: Decodable {
        var min: Vec3
        var max: Vec3
    }

    /// The identity, kind, value, unit, size class and region are required; a feature
    /// missing any of them is skipped by `FeatureTable.decode`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(FeatureKind.self, forKey: .kind)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? id
        designValue = try container.decode(Double.self, forKey: .designValue)
        unit = try container.decode(FeatureUnit.self, forKey: .unit)
        sizeClass = try container.decode(SizeClass.self, forKey: .sizeClass)
        sizeMillimetres = try container.decodeIfPresent(Double.self, forKey: .sizeMillimetres) ?? designValue
        howToMeasure = try container.decodeIfPresent(String.self, forKey: .howToMeasure) ?? ""
        let corners = try container.decode(RegionCorners.self, forKey: .region)
        region = Box(minimum: corners.min, maximum: corners.max)
    }
}

/// The reference object's feature table (FR-8.4), read from the JSON file the
/// reference-object script writes.
public struct FeatureTable: Equatable, Sendable {
    public var version: Int
    /// Features up to this size (mm) are small.
    public var smallLimit: Double
    /// Features up to this size (mm), and over `smallLimit`, are medium.
    public var mediumLimit: Double
    public var features: [ReferenceFeature]
    /// Entries in the file that could not be read and were left out.
    public var skippedFeatures: Int

    public init(
        version: Int = 1,
        smallLimit: Double = 5,
        mediumLimit: Double = 30,
        features: [ReferenceFeature],
        skippedFeatures: Int = 0
    ) {
        self.version = version
        self.smallLimit = smallLimit
        self.mediumLimit = mediumLimit
        self.features = features
        self.skippedFeatures = skippedFeatures
    }

    public func feature(_ id: String) -> ReferenceFeature? {
        features.first { $0.id == id }
    }

    /// For example "Small (up to 5 mm)", "Medium (5–30 mm)", "Large (over 30 mm)".
    public func label(for sizeClass: SizeClass) -> String {
        let small = Self.number(smallLimit)
        let medium = Self.number(mediumLimit)
        switch sizeClass {
        case .small: return "Small (up to \(small) mm)"
        case .medium: return "Medium (\(small)–\(medium) mm)"
        case .large: return "Large (over \(medium) mm)"
        }
    }

    /// Reads the table. Reading is forgiving, like the scan manifest: unknown fields
    /// are ignored, missing optional fields take defaults, and a feature that cannot be
    /// read is skipped and counted rather than spoiling the whole table.
    public static func decode(_ data: Data) throws -> FeatureTable {
        let file: TableFile
        do {
            file = try JSONDecoder().decode(TableFile.self, from: data)
        } catch {
            throw ReferenceError.malformedTable("it is not a feature table")
        }
        let features = file.features.compactMap(\.value)
        let ids = Set(features.map(\.id))
        guard ids.count == features.count else { throw ReferenceError.malformedTable("two features share an ID") }
        return FeatureTable(
            version: file.version ?? 1, smallLimit: file.sizeClasses?.small ?? 5,
            mediumLimit: file.sizeClasses?.medium ?? 30, features: features,
            skippedFeatures: file.features.count - features.count)
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    private struct TableFile: Decodable {
        var version: Int?
        var sizeClasses: SizeLimits?
        var features: [Lossy<ReferenceFeature>]
    }
}

/// The `sizeClasses` entry of the feature table: the upper limits in millimetres.
private struct SizeLimits: Decodable {
    var small: Double?
    var medium: Double?
}

/// Decodes a value if it can, and otherwise holds `nil` instead of failing the whole
/// file.
struct Lossy<Value: Decodable>: Decodable {
    var value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// Why the reference object could not be used.
public enum ReferenceError: Error, Equatable, Sendable {
    /// The shape file is missing or damaged.
    case malformedShape(String)
    /// The feature table is missing or damaged.
    case malformedTable(String)
    /// The shape has no area, or is flat, so a scan cannot be lined up with it.
    case degenerateShape
    /// No feature has this ID.
    case unknownFeature(String)
}

extension ReferenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .malformedShape(let reason):
            return "The reference object's shape could not be read: \(reason). Reinstall the app."
        case .malformedTable(let reason):
            return "The reference object's feature table could not be read: \(reason). Reinstall the app."
        case .degenerateShape:
            return "The reference object's shape is flat or empty, so scans cannot be compared with it."
        case .unknownFeature(let id):
            return "There is no feature \(id) on the reference object."
        }
    }
}

/// The known truth (ReferenceModel in components.md): the reference object's exact
/// shape, in metres like every mesh in the app, and its feature table.
public struct ReferenceObject: Sendable {
    public let mesh: Mesh
    public let table: FeatureTable

    public init(mesh: Mesh, table: FeatureTable) {
        self.mesh = mesh
        self.table = table
    }

    /// Reads the shape from the script's binary STL (millimetres, turned into metres
    /// here) and the feature table from its JSON.
    public static func load(stlData: Data, featureTableData: Data) throws -> ReferenceObject {
        let mesh: Mesh
        do {
            mesh = try MeshFiles.parseBinarySTL(stlData, unit: .millimetres)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? "unknown error"
            throw ReferenceError.malformedShape(reason)
        }
        guard !mesh.isEmpty else { throw ReferenceError.degenerateShape }
        return ReferenceObject(mesh: mesh, table: try FeatureTable.decode(featureTableData))
    }
}
