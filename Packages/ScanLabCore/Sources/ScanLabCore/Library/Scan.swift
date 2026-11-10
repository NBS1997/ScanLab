import Foundation

/// How a scan was made.
public enum CaptureMethod: String, Codable, CaseIterable, Sendable {
    /// Moving the phone over the surfaces with the depth sensor (unit U07).
    case sweep
    /// Photographs taken around the object, built into a model on the phone (unit U08).
    case photos
    /// The built-in sample model, added from Diagnostics so the library can be tried
    /// before capture exists.
    case sample

    /// The word shown on screen, for example "Photos".
    public var displayName: String {
        switch self {
        case .sweep: "Sweep"
        case .photos: "Photos"
        case .sample: "Sample"
        }
    }
}

/// One saved scan's manifest: everything the library shows about it without opening
/// the model itself (ADR-007). It is stored as `manifest.json` in the scan's folder.
///
/// Reading is forgiving on purpose (business rule SL-9): fields added by later builds
/// are ignored, and fields missing from older manifests take sensible defaults, so a
/// manifest written by any build can still be read after an update (FR-6.3).
public struct Scan: Identifiable, Equatable, Sendable {
    /// The manifest layout this build writes. Raise it when the meaning of a field
    /// changes; adding a field does not need it.
    public static let currentVersion = 1

    /// Which manifest layout this was written with.
    public var version: Int
    public let id: UUID
    public var name: String
    public var method: CaptureMethod
    /// When the scan was saved, to the whole second.
    public var createdAt: Date
    /// The detail level the model was built at, for example "reduced" for a photo
    /// model built on the phone (FR-4.2). `nil` when it does not apply.
    public var detailLevel: String?
    public var faceCount: Int
    /// The overall size in metres (width, depth, height), or `nil` for a model with no
    /// faces.
    public var size: Vec3?
    /// Whether this scan is of the printed reference object (unit U10).
    public var isReference: Bool
    /// Whether an accuracy report is stored with the scan (unit U10).
    public var hasAccuracyReport: Bool
    /// How much storage the kept raw capture uses, or `nil` when there is none (FR-6.6).
    public var rawCaptureBytes: Int64?

    public init(
        id: UUID = UUID(),
        name: String,
        method: CaptureMethod,
        createdAt: Date,
        detailLevel: String? = nil,
        faceCount: Int = 0,
        size: Vec3? = nil,
        isReference: Bool = false,
        hasAccuracyReport: Bool = false,
        rawCaptureBytes: Int64? = nil
    ) {
        self.version = Self.currentVersion
        self.id = id
        self.name = name
        self.method = method
        self.createdAt = createdAt
        self.detailLevel = detailLevel
        self.faceCount = faceCount
        self.size = size
        self.isReference = isReference
        self.hasAccuracyReport = hasAccuracyReport
        self.rawCaptureBytes = rawCaptureBytes
    }
}

extension Scan: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case id
        case name
        case method
        case createdAt
        case detailLevel
        case faceCount
        case size
        case isReference
        case hasAccuracyReport
        case rawCaptureBytes
    }

    /// Only the identity, name, method and date are required. Everything else falls
    /// back to a default when missing, so older manifests stay readable.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        method = try container.decode(CaptureMethod.self, forKey: .method)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        detailLevel = try container.decodeIfPresent(String.self, forKey: .detailLevel)
        faceCount = try container.decodeIfPresent(Int.self, forKey: .faceCount) ?? 0
        size = try container.decodeIfPresent(Vec3.self, forKey: .size)
        isReference = try container.decodeIfPresent(Bool.self, forKey: .isReference) ?? false
        hasAccuracyReport = try container.decodeIfPresent(Bool.self, forKey: .hasAccuracyReport) ?? false
        rawCaptureBytes = try container.decodeIfPresent(Int64.self, forKey: .rawCaptureBytes)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(method, forKey: .method)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(detailLevel, forKey: .detailLevel)
        try container.encode(faceCount, forKey: .faceCount)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encode(isReference, forKey: .isReference)
        try container.encode(hasAccuracyReport, forKey: .hasAccuracyReport)
        try container.encodeIfPresent(rawCaptureBytes, forKey: .rawCaptureBytes)
    }
}

/// A point is stored in a manifest as a list of three numbers, `[x, y, z]`.
extension Vec3: Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Double.self)
        let y = try container.decode(Double.self)
        let z = try container.decode(Double.self)
        self.init(x, y, z)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
        try container.encode(z)
    }
}

/// Turns manifests into JSON and back. Dates are ISO 8601 text in UTC, so a manifest
/// is readable by eye if it is ever exported.
public enum ManifestCodec {
    public static func encode(_ scan: Scan) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(scan)
        } catch {
            throw StoreError.writeFailed("the scan details could not be encoded")
        }
    }

    public static func decode(_ data: Data) throws -> Scan {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Scan.self, from: data)
        } catch {
            throw StoreError.corrupt("the scan details could not be read")
        }
    }
}
