import Foundation
import Testing

@testable import ScanLabCore

@Suite("Units")
struct UnitsTests {
    @Test("lengths under 1 m are shown in millimetres to 0.1 mm")
    func millimetres() {
        #expect(Units.format(0.06) == "60.0 mm")
        #expect(Units.format(0.0125) == "12.5 mm")
        #expect(Units.format(0.9994) == "999.4 mm")
        #expect(Units.format(0) == "0.0 mm")
    }

    @Test("lengths of 1 m or more are shown in metres to the millimetre")
    func metres() {
        #expect(Units.format(1) == "1.000 m")
        #expect(Units.format(1.25) == "1.250 m")
        #expect(Units.format(1234.5) == "1,234.500 m")
    }

    @Test("a length that would round up to 1,000.0 mm is shown in metres instead")
    func roundingBoundary() {
        #expect(Units.format(0.99999) == "1.000 m")
    }

    @Test("a length that is not a number is shown as unknown")
    func notANumber() {
        #expect(Units.format(.nan) == "unknown")
        #expect(Units.format(.infinity) == "unknown")
    }

    @Test("dimensions share one unit")
    func dimensions() {
        #expect(Units.formatDimensions(Vec3(0.06, 0.04, 0.02)) == "60.0 × 40.0 × 20.0 mm")
        #expect(Units.formatDimensions(Vec3(1.2, 0.04, 0.02)) == "1.200 × 0.040 × 0.020 m")
        #expect(Units.formatDimensions(Vec3(0.01, .nan, 0)) == "unknown")
    }

    @Test("face counts are grouped in thousands and singular for one")
    func faceCounts() {
        #expect(Units.faceCount(19_840) == "19,840 faces")
        #expect(Units.faceCount(1) == "1 face")
        #expect(Units.faceCount(0) == "0 faces")
    }
}
