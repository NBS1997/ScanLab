import Foundation
import Observation
import ScanLabCore

/// What the Reference object sheet shows (mockups.md, supporting sheets; US-12,
/// FR-8.6): every feature from the measurement sheet with its design value and a box
/// for the owner's caliper value.
@MainActor
@Observable
final class ReferenceObjectModel {
    /// One feature's line on the sheet.
    struct Row: Identifiable {
        let feature: ReferenceFeature
        /// Exactly what the owner typed.
        var text: String
        var check: CaliperCheck

        var id: String { feature.id }
    }

    enum Phase {
        case loading
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var rows: [Row] = []
    /// Shown in place when saving fails.
    private(set) var saveError: String?
    private var table: FeatureTable?
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// The feature kinds present, in the measurement sheet's order.
    var kinds: [FeatureKind] {
        FeatureKind.allCases.filter { kind in rows.contains { $0.feature.kind == kind } }
    }

    func rows(of kind: FeatureKind) -> [Row] {
        rows.filter { $0.feature.kind == kind }
    }

    /// Saving is possible when no box holds something unusable.
    var canSave: Bool {
        rows.allSatisfy {
            if case .invalid = $0.check { return false }
            return true
        }
    }

    var enteredCount: Int {
        rows.filter {
            if case .valid = $0.check { return true }
            return false
        }.count
    }

    /// Reads the feature table from the app and the saved values from the phone.
    func load() async {
        do {
            let table = try await environment.reference.table()
            let sheet = try environment.calipers.load()
            self.table = table
            rows = table.features.map { feature in
                let text = sheet.values[feature.id].map(CaliperValidation.format) ?? ""
                return Row(feature: feature, text: text, check: CaliperValidation.check(text, for: feature))
            }
            phase = .ready
            environment.log.info(
                "accuracy", "Reference object sheet shown",
                ["features": String(table.features.count), "entered": String(sheet.enteredCount)])
        } catch {
            let reason = error.localizedDescription
            phase = .failed(reason)
            environment.log.error("accuracy", "Reference object sheet not loaded", ["reason": reason])
        }
    }

    /// Takes what the owner typed into a box and checks it straight away.
    func update(_ id: String, text: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].text = text
        rows[index].check = CaliperValidation.check(text, for: rows[index].feature)
    }

    /// Saves every usable value; blank boxes are left out. Returns whether it worked.
    func save() -> Bool {
        saveError = nil
        guard let table, canSave else { return false }
        var sheet = CaliperSheet(tableVersion: table.version, updatedAt: Date())
        do {
            for row in rows {
                guard case .valid(let value, _) = row.check else { continue }
                try sheet.set(value, for: row.id, in: table)
            }
            try environment.calipers.save(sheet)
            let warnings = rows.filter {
                if case .valid(_, .some) = $0.check { return true }
                return false
            }.count
            environment.log.info(
                "accuracy", "Caliper values saved",
                ["entered": String(sheet.enteredCount), "warnings": String(warnings)])
            return true
        } catch {
            saveError = error.localizedDescription
            environment.log.error("accuracy", "Caliper values not saved", ["reason": error.localizedDescription])
            return false
        }
    }
}
