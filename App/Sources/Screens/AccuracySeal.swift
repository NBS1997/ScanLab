import ScanLabCore
import SwiftUI

/// The seal shown beside a scan that has an accuracy report, in the library list and
/// on Scan detail. It shows the report's verdict level, read from the manifest
/// (`Scan.accuracyVerdict`), so a limited or unreliable report never looks like a pass:
///
/// - good: green filled seal with a tick, "Accuracy report: good";
/// - limited: orange warning triangle, "Accuracy report: limited";
/// - unreliable: grey seal with a cross, "Accuracy report: unreliable";
/// - level unknown (checked by a build before the level was kept): grey plain seal,
///   "Has an accuracy report". Checking again fills the level in.
struct AccuracySeal {
    let symbol: String
    let colour: Color
    let label: String

    /// The seal for `scan`, or `nil` when it has no accuracy report.
    init?(_ scan: Scan) {
        guard scan.hasAccuracyReport else { return nil }
        switch scan.accuracyVerdict.flatMap(VerdictLevel.init(rawValue:)) {
        case .good:
            self.init(symbol: "checkmark.seal.fill", colour: .green, label: "Accuracy report: good")
        case .limited:
            self.init(symbol: "exclamationmark.triangle.fill", colour: .orange, label: "Accuracy report: limited")
        case .unreliable:
            self.init(symbol: "xmark.seal", colour: .gray, label: "Accuracy report: unreliable")
        case nil:
            self.init(symbol: "seal", colour: .gray, label: "Has an accuracy report")
        }
    }

    private init(symbol: String, colour: Color, label: String) {
        self.symbol = symbol
        self.colour = colour
        self.label = label
    }
}
