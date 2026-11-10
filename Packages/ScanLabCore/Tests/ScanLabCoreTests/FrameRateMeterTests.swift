import Foundation
import Testing

@testable import ScanLabCore

@Suite("Frame rate meter")
struct FrameRateMeterTests {
    private func approximately(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 0.01
    }

    @Test("a steady 60 frames a second reads 60")
    func steadyRate() {
        var meter = FrameRateMeter()
        for frame in 0..<120 {
            meter.record(Double(frame) / 60)
        }
        #expect(approximately(meter.framesPerSecond, 60))
        // Only about a second of history is kept.
        #expect(meter.timestamps.count <= 61)
    }

    @Test("a single frame has no rate")
    func singleFrame() {
        var meter = FrameRateMeter()
        meter.record(10)
        #expect(meter.framesPerSecond == nil)
        meter.record(10)
        #expect(meter.framesPerSecond == nil)
    }

    @Test("after a long pause the rate comes only from new frames")
    func gap() {
        var meter = FrameRateMeter(window: 1)
        for frame in 0..<30 {
            meter.record(Double(frame) / 30)
        }
        meter.record(10)
        #expect(meter.framesPerSecond == nil)
        meter.record(10.1)
        #expect(approximately(meter.framesPerSecond, 10))
    }

    @Test("late frames are put in order; very old ones are ignored")
    func outOfOrder() {
        var meter = FrameRateMeter(window: 1)
        meter.record(0.5)
        meter.record(0.0)
        meter.record(0.25)
        #expect(meter.timestamps == [0.0, 0.25, 0.5])
        #expect(approximately(meter.framesPerSecond, 4))
        meter.record(5)
        meter.record(1)
        #expect(meter.timestamps == [5])
    }

    @Test("uneven spacing reads the average rate")
    func unevenTimestamps() {
        var meter = FrameRateMeter(window: 2)
        for time in [0.0, 0.01, 0.2, 0.21, 0.5] {
            meter.record(time)
        }
        #expect(approximately(meter.framesPerSecond, 8))
    }

    @Test("bad input is ignored and reset clears history")
    func badInputAndReset() {
        var meter = FrameRateMeter(window: -4)
        #expect(meter.window == 0.01)
        meter.record(.nan)
        meter.record(.infinity)
        #expect(meter.timestamps.isEmpty)
        meter.record(1)
        meter.reset()
        #expect(meter.timestamps.isEmpty)
        #expect(FrameRateMeter(window: .infinity).window == 1)
    }
}
