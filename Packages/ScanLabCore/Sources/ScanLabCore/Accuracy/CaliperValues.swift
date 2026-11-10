import Foundation

/// The owner's caliper measurements of the printed reference object (FR-8.6): one
/// value per feature, in the feature's own unit (millimetres or degrees). A feature
/// left blank simply has no entry.
///
/// Stored as JSON on the phone and read forgivingly, like the scan manifest, so values
/// entered in one build survive every later one.
public struct CaliperSheet: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    /// The feature table version the values were measured against.
    public var tableVersion: Int
    /// Feature ID → measured value.
    public var values: [String: Double]
    /// When the values were last saved.
    public var updatedAt: Date?

    public init(tableVersion: Int = 1, values: [String: Double] = [:], updatedAt: Date? = nil) {
        self.version = Self.currentVersion
        self.tableVersion = tableVersion
        self.values = values
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case tableVersion
        case values
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        tableVersion = try container.decodeIfPresent(Int.self, forKey: .tableVersion) ?? 1
        values = try container.decodeIfPresent([String: Double].self, forKey: .values) ?? [:]
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// How many features have a value.
    public var enteredCount: Int { values.count }

    /// Records the owner's value for a feature, or clears it when `value` is `nil`.
    /// The value must pass `CaliperValidation`; warnings do not stop it being kept.
    public mutating func set(_ value: Double?, for featureID: String, in table: FeatureTable) throws {
        guard let feature = table.feature(featureID) else { throw ReferenceError.unknownFeature(featureID) }
        guard let value else {
            values[featureID] = nil
            return
        }
        if case .invalid(let reason) = CaliperValidation.check(value, for: feature) {
            throw CaliperError.invalid(featureID: featureID, reason: reason)
        }
        values[featureID] = value
    }

    /// The sheet as JSON, with dates as ISO 8601 text.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads a sheet written by `encoded()`, from this build or any other.
    public static func decode(_ data: Data) throws -> CaliperSheet {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(CaliperSheet.self, from: data)
        } catch {
            throw CaliperError.unreadable
        }
    }
}

/// Why a caliper value or the saved values could not be used.
public enum CaliperError: Error, Equatable, Sendable {
    case invalid(featureID: String, reason: String)
    case unreadable
}

extension CaliperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalid(let featureID, let reason):
            return "\(featureID): \(reason)"
        case .unreadable:
            return "The saved caliper values could not be read. Enter them again from the measurement sheet."
        }
    }
}

/// The result of checking one typed caliper value.
public enum CaliperCheck: Equatable, Sendable {
    /// Nothing typed: the feature is left out.
    case empty
    /// A usable value, with an optional reason to measure again.
    case valid(Double, warning: String?)
    /// Not usable; the reason says what to fix.
    case invalid(String)
}

/// The checks on a caliper value (business rules AC-2 to AC-4).
///
/// - It must be a number above zero.
/// - Lengths must be at most 500 mm (the object is 160 mm long) and angles at most
///   90 degrees (the sheet asks for the acute angle).
/// - It must be within reach of the design value: a length may differ by at most 2 mm
///   or half the design value, whichever is more, and an angle by at most 15 degrees.
///   Anything further is almost certainly a slipped decimal point or the wrong feature.
/// - A length more than 0.5 mm from the design value (2 degrees for an angle) is kept,
///   but with a warning to measure again, as the measurement sheet advises.
public enum CaliperValidation {
    public static let maximumLength = 500.0
    public static let maximumAngle = 90.0

    /// Checks what the owner typed. Spaces, a trailing "mm" or "°", and a comma as the
    /// decimal point are accepted.
    public static func check(_ text: String, for feature: ReferenceFeature) -> CaliperCheck {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for suffix in ["mm", "°", "deg"] where cleaned.hasSuffix(suffix) {
            cleaned = String(cleaned.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        }
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return .empty }
        guard let value = Double(cleaned) else { return .invalid("Type a number, such as 12.05.") }
        return check(value, for: feature)
    }

    /// Checks a value already read as a number.
    public static func check(_ value: Double, for feature: ReferenceFeature) -> CaliperCheck {
        guard value.isFinite else { return .invalid("Type a number, such as 12.05.") }
        guard value > 0 else { return .invalid("Must be more than zero.") }
        switch feature.unit {
        case .millimetres: return checkLength(value, design: feature.designValue)
        case .degrees: return checkAngle(value, design: feature.designValue)
        }
    }

    private static func checkLength(_ value: Double, design: Double) -> CaliperCheck {
        let difference = abs(value - design)
        if value > maximumLength {
            return .invalid("Must be \(format(maximumLength)) mm or less.")
        }
        if difference > max(2, design / 2) {
            return .invalid("Too far from the design value (\(format(design)) mm). Check the decimal point.")
        }
        if difference > 0.5 {
            let warning = "More than 0.5 mm from the design value (\(format(design)) mm). Measure again."
            return .valid(value, warning: warning)
        }
        return .valid(value, warning: nil)
    }

    private static func checkAngle(_ value: Double, design: Double) -> CaliperCheck {
        let difference = abs(value - design)
        if value > maximumAngle {
            return .invalid("Must be 90° or less. If the protractor reads more than 90, write 180 minus it.")
        }
        if difference > 15 {
            return .invalid("Too far from the design value (\(format(design))°). Check the reading.")
        }
        if difference > 2 {
            return .valid(value, warning: "More than 2° from the design value (\(format(design))°). Measure again.")
        }
        return .valid(value, warning: nil)
    }

    /// A value as typed back to the owner: up to three decimal places, no trailing
    /// zeros, "." as the decimal point.
    public static func format(_ value: Double) -> String {
        let text = String(format: "%.3f", value)
        var trimmed = Substring(text)
        while trimmed.hasSuffix("0") { trimmed = trimmed.dropLast() }
        if trimmed.hasSuffix(".") { trimmed = trimmed.dropLast() }
        return String(trimmed)
    }
}
