import Foundation

/// The rules for scan names (business rules SL-3 and SL-4).
public enum ScanNaming {
    /// The longest name allowed, in characters. Long enough for a description, short
    /// enough to fit a list row on two lines.
    public static let maximumLength = 80

    /// The name as it will be stored: spaces and line breaks trimmed from both ends.
    /// Throws when nothing is left, or when it is longer than `maximumLength`.
    public static func validated(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyName }
        guard trimmed.count <= maximumLength else { throw StoreError.nameTooLong(maximum: maximumLength) }
        return trimmed
    }

    /// The name a new scan gets until it is renamed: the method and when it was made,
    /// for example "Sweep 11 Nov 14:05". Names do not have to be different from each
    /// other; scans are told apart by their identity.
    public static func defaultName(method: CaptureMethod, date: Date, timeZone: TimeZone = .current) -> String {
        "\(method.displayName) \(dateText(date, timeZone: timeZone))"
    }

    /// Day, short month and 24-hour time, for example "11 Nov 14:05", in Australian
    /// English whatever the phone's region.
    public static func dateText(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: date)
    }

    /// Day and short month only, for list rows: "11 Nov".
    public static func shortDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
