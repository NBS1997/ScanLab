import Foundation

/// How lengths and counts are shown to the owner (FR-6.4, requirements Q6-B):
/// millimetres, or metres once a length reaches 1 m. Always metric, written the
/// Australian way ("1,234.5"), whatever the phone's region.
public enum Units {
    public static let millimetresPerMetre = 1000.0

    private static let australian = Locale(identifier: "en_AU")

    /// One length, for example "60.0 mm" or "1.250 m". Shown as "unknown" when the
    /// value is not a real number.
    public static func format(_ metres: Double) -> String {
        guard metres.isFinite else { return "unknown" }
        return usesMetres([metres]) ? metresText(metres) + " m" : millimetresText(metres) + " mm"
    }

    /// Overall dimensions, for example "60.0 × 40.0 × 20.0 mm". All three use the same
    /// unit: metres if any of them is 1 m or more.
    public static func formatDimensions(_ size: Vec3) -> String {
        let values = [size.x, size.y, size.z]
        guard values.allSatisfy(\.isFinite) else { return "unknown" }
        if usesMetres(values) {
            return values.map(metresText).joined(separator: " × ") + " m"
        }
        return values.map(millimetresText).joined(separator: " × ") + " mm"
    }

    /// "19,840 faces", or "1 face".
    public static func faceCount(_ count: Int) -> String {
        let number = count.formatted(.number.locale(australian))
        return count == 1 ? "1 face" : "\(number) faces"
    }

    /// Metres when any value would show as 1,000.0 mm or more. Deciding after
    /// rounding avoids showing "1,000.0 mm" for 0.99999 m.
    private static func usesMetres(_ values: [Double]) -> Bool {
        values.contains { ($0 * millimetresPerMetre * 10).rounded().magnitude >= 10_000 }
    }

    private static func millimetresText(_ metres: Double) -> String {
        number(metres * millimetresPerMetre, decimals: 1)
    }

    private static func metresText(_ metres: Double) -> String {
        number(metres, decimals: 3)
    }

    private static func number(_ value: Double, decimals: Int) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(australian))
    }
}
