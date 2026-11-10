import Testing

@testable import ScanLabCore

@Suite("Readout text")
struct ReadoutTextTests {
    @Test("below 1 m reads in millimetres, from 1 m in metres")
    func distances() {
        #expect(ReadoutText.distance(metres: 0.845) == "845 mm")
        #expect(ReadoutText.distance(metres: 1.0) == "1.00 m")
        #expect(ReadoutText.distance(metres: 1.234) == "1.23 m")
        #expect(ReadoutText.spokenDistance(metres: 0.845) == "845 millimetres")
        #expect(ReadoutText.spokenDistance(metres: 2.5) == "2.50 metres")
    }

    @Test("a reading that rounds up to 1,000 mm is shown in metres")
    func roundingBoundary() {
        #expect(ReadoutText.distance(metres: 0.9996) == "1.00 m")
        #expect(ReadoutText.distance(metres: 0.9994) == "999 mm")
        #expect(ReadoutText.spokenDistance(metres: 0.001) == "1 millimetre")
    }

    @Test("no reading shows a dash and says so")
    func noReading() {
        #expect(ReadoutText.distance(metres: nil) == "—")
        #expect(ReadoutText.distance(metres: .nan) == "—")
        #expect(ReadoutText.distance(metres: 0) == "—")
        #expect(ReadoutText.spokenDistance(metres: nil) == "No reading")
        #expect(ReadoutText.spokenDistance(metres: -2) == "No reading")
    }

    @Test("frame rate is whole frames per second")
    func frameRate() {
        #expect(ReadoutText.frameRate(59.7) == "60 fps")
        #expect(ReadoutText.frameRate(nil) == "— fps")
        #expect(ReadoutText.frameRate(.infinity) == "— fps")
        #expect(ReadoutText.spokenFrameRate(30.2) == "30 frames per second")
        #expect(ReadoutText.spokenFrameRate(nil) == "Not measured yet")
    }

    @Test("legend distances drop a needless decimal")
    func legend() {
        #expect(ReadoutText.legendDistance(metres: 0.2) == "0.2 m")
        #expect(ReadoutText.legendDistance(metres: 5) == "5 m")
        #expect(ReadoutText.legendDistance(metres: 2.6) == "2.6 m")
    }
}
