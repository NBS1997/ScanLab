import Foundation
import Testing

@testable import ScanLabCore

@Suite("Caliper values")
struct CaliperValuesTests {
    private let hole = ReferenceFeature(
        id: "H3", kind: .hole, designValue: 12, sizeClass: .medium, region: Box(minimum: .zero, maximum: .zero))
    private let rib = ReferenceFeature(
        id: "L1", kind: .length, designValue: 1.6, sizeClass: .small, region: Box(minimum: .zero, maximum: .zero))
    private let angle = ReferenceFeature(
        id: "A2", kind: .angle, designValue: 30, unit: .degrees, sizeClass: .medium,
        region: Box(minimum: .zero, maximum: .zero))

    private var table: FeatureTable { FeatureTable(features: [hole, rib, angle]) }

    @Test("typed values are read with spaces, units and a decimal comma")
    func parsing() {
        #expect(CaliperValidation.check(" 12.05 ", for: hole) == .valid(12.05, warning: nil))
        #expect(CaliperValidation.check("12,05mm", for: hole) == .valid(12.05, warning: nil))
        #expect(CaliperValidation.check("30.5°", for: angle) == .valid(30.5, warning: nil))
        #expect(CaliperValidation.check("   ", for: hole) == .empty)
        #expect(CaliperValidation.check("twelve", for: hole) == .invalid("Type a number, such as 12.05."))
    }

    @Test("zero, negative, endless and huge values are refused")
    func limits() {
        #expect(CaliperValidation.check("0", for: hole) == .invalid("Must be more than zero."))
        #expect(CaliperValidation.check("-3", for: hole) == .invalid("Must be more than zero."))
        #expect(CaliperValidation.check(Double.infinity, for: hole) == .invalid("Type a number, such as 12.05."))
        #expect(CaliperValidation.check("1205", for: hole) == .invalid("Must be 500 mm or less."))
        #expect(CaliperValidation.check("95", for: angle) != .empty)
        if case .invalid = CaliperValidation.check("95", for: angle) {} else { Issue.record("95° accepted") }
    }

    @Test("a value far from the design is refused; a little off gives a warning")
    func nearDesign() {
        if case .invalid = CaliperValidation.check("120.5", for: hole) {} else { Issue.record("120.5 accepted") }
        if case .invalid = CaliperValidation.check("3.7", for: rib) {} else { Issue.record("3.7 accepted") }
        if case .valid(let value, let warning) = CaliperValidation.check("12.8", for: hole) {
            #expect(value == 12.8)
            #expect(warning?.contains("Measure again") == true)
        } else {
            Issue.record("12.8 refused")
        }
        if case .valid(_, let warning) = CaliperValidation.check("33", for: angle) {
            #expect(warning?.contains("30°") == true)
        } else {
            Issue.record("33° refused")
        }
        if case .invalid = CaliperValidation.check("50", for: angle) {} else { Issue.record("50° accepted") }
    }

    @Test("values are formatted without trailing zeros")
    func formatting() {
        #expect(CaliperValidation.format(12) == "12")
        #expect(CaliperValidation.format(12.05) == "12.05")
        #expect(CaliperValidation.format(1.6) == "1.6")
    }

    @Test("the sheet keeps valid values, clears blanks and refuses bad or unknown ones")
    func sheet() throws {
        var sheet = CaliperSheet()
        try sheet.set(11.9, for: "H3", in: table)
        try sheet.set(1.62, for: "L1", in: table)
        #expect(sheet.enteredCount == 2)
        try sheet.set(nil, for: "L1", in: table)
        #expect(sheet.values == ["H3": 11.9])
        #expect(throws: CaliperError.self) { try sheet.set(-1, for: "H3", in: table) }
        #expect(throws: ReferenceError.unknownFeature("Z9")) { try sheet.set(1, for: "Z9", in: table) }
        #expect(sheet.values == ["H3": 11.9])
    }

    @Test("the sheet survives being saved and read back, and old files read forgivingly")
    func codec() throws {
        let saved = Date(timeIntervalSince1970: 1_800_000_000)
        let sheet = CaliperSheet(values: ["H3": 11.9, "A2": 29.5], updatedAt: saved)
        #expect(try CaliperSheet.decode(sheet.encoded()) == sheet)
        let old = try CaliperSheet.decode(Data(#"{"values": {"L1": 1.6}, "future": 1}"#.utf8))
        #expect(old.values == ["L1": 1.6] && old.version == 1 && old.updatedAt == nil)
        #expect(throws: CaliperError.unreadable) { try CaliperSheet.decode(Data("nonsense".utf8)) }
        #expect(CaliperError.unreadable.errorDescription?.isEmpty == false)
        #expect(CaliperError.invalid(featureID: "H3", reason: "Bad.").errorDescription == "H3: Bad.")
    }
}
