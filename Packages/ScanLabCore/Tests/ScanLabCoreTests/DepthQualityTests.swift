import Testing

@testable import ScanLabCore

@Suite("Poor-depth advisor")
struct PoorDepthAdvisorTests {
    private let high = ConfidenceLevel.high.rawValue
    private let low = ConfidenceLevel.low.rawValue

    private func input(_ metres: Float, count: Int = 100, confidence: UInt8? = nil) -> DepthQualityInput {
        DepthQualityInput(
            depths: [Float](repeating: metres, count: count),
            confidence: confidence.map { [UInt8](repeating: $0, count: count) } ?? [])
    }

    @Test("a full, confident square at a sensible distance needs no hint")
    func good() {
        #expect(PoorDepthAdvisor.advice(for: input(0.6, confidence: high)) == .good)
        // Far but clean is still good: the hint is for poor depth only.
        #expect(PoorDepthAdvisor.advice(for: input(3.0, confidence: high)) == .good)
        // No confidence values: judged on missing readings alone.
        #expect(PoorDepthAdvisor.advice(for: input(0.6)) == .good)
    }

    @Test("nearer than the sensor's reliable minimum says move back")
    func tooClose() {
        #expect(PoorDepthAdvisor.advice(for: input(0.12, confidence: high)) == .moveBack)
    }

    @Test("mostly low confidence at range says move closer")
    func lowConfidenceAtRange() {
        #expect(PoorDepthAdvisor.advice(for: input(1.8, confidence: low)) == .moveCloser)
    }

    @Test("a dark object with many missing readings says move closer")
    func darkObject() {
        // 40 of 100 pixels missing at 0.8 m, as on a dark remote.
        var depths = [Float](repeating: 0.8, count: 100)
        for index in 0..<40 {
            depths[index] = index.isMultiple(of: 2) ? .nan : 0
        }
        let advice = PoorDepthAdvisor.advice(for: DepthQualityInput(depths: depths))
        #expect(advice == .moveCloser)
        #expect(advice.hint == "Move closer")
    }

    @Test("poor depth very near says move back")
    func poorAndNear() {
        #expect(PoorDepthAdvisor.advice(for: input(0.25, confidence: low)) == .moveBack)
    }

    @Test("all readings missing: move back if last seen very near, otherwise move closer")
    func allInvalid() {
        let missing = [Float](repeating: .nan, count: 50)
        #expect(PoorDepthAdvisor.advice(for: DepthQualityInput(depths: missing)) == .moveCloser)
        #expect(PoorDepthAdvisor.advice(for: DepthQualityInput(depths: missing, recentDistance: 1.5)) == .moveCloser)
        #expect(PoorDepthAdvisor.advice(for: DepthQualityInput(depths: missing, recentDistance: 0.15)) == .moveBack)
    }

    @Test("no input gives no hint")
    func emptyInput() {
        #expect(PoorDepthAdvisor.advice(for: DepthQualityInput(depths: [])) == .good)
    }

    @Test("a confidence list of the wrong length is ignored")
    func mismatchedConfidence() {
        let mismatched = DepthQualityInput(depths: [Float](repeating: 0.6, count: 10), confidence: [low, low])
        #expect(PoorDepthAdvisor.advice(for: mismatched) == .good)
    }

    @Test("hints and log names")
    func words() {
        #expect(DepthAdvice.good.hint == nil)
        #expect(DepthAdvice.moveBack.hint == "Move back")
        #expect(Set([DepthAdvice.good, .moveCloser, .moveBack].map(\.logName)).count == 3)
    }
}

@Suite("Depth quality input")
struct DepthQualityInputTests {
    @Test("the centre square is copied with its confidence")
    func centreSquare() throws {
        // A 5 × 3 frame numbered 0…14; the 3 × 3 centre holds 1, 2, 3, 6, 7, 8, 11, 12, 13.
        let depths = (0..<15).map(Float.init)
        let confidence = (0..<15).map { UInt8($0 % 3) }
        let frame = try #require(DepthFrame(width: 5, height: 3, depths: depths, confidence: confidence))
        let square = DepthQualityInput.centre(of: frame, side: 3, recentDistance: 0.5)
        #expect(square.depths == [1, 2, 3, 6, 7, 8, 11, 12, 13])
        #expect(square.confidence == [1, 2, 0, 0, 1, 2, 2, 0, 1])
        #expect(square.recentDistance == 0.5)
    }

    @Test("a square larger than the frame is clamped, and no confidence stays empty")
    func clamped() throws {
        let frame = try #require(DepthFrame(width: 2, height: 2, depths: [1, 2, 3, 4]))
        let square = DepthQualityInput.centre(of: frame, side: 50)
        #expect(square.depths == [1, 2, 3, 4])
        #expect(square.confidence.isEmpty)
        #expect(DepthQualityInput.centre(of: frame, side: 0).depths.count == 1)
    }
}

@Suite("Steady value")
struct SteadyValueTests {
    @Test("a new value is shown only after it has held for the hold time")
    func holds() {
        var steady = SteadyValue(DepthAdvice.good, holdSeconds: 1)
        let changed1 = steady.update(.moveCloser, at: 0)
        #expect(!changed1)
        let changed2 = steady.update(.moveCloser, at: 0.5)
        #expect(!changed2)
        #expect(steady.shown == .good)
        let changed3 = steady.update(.moveCloser, at: 1.0)
        #expect(changed3)
        #expect(steady.shown == .moveCloser)
        let changed4 = steady.update(.moveCloser, at: 2.0)
        #expect(!changed4)
    }

    @Test("a flicker back to the shown value resets the wait")
    func flicker() {
        var steady = SteadyValue(DepthAdvice.good, holdSeconds: 1)
        steady.update(.moveBack, at: 0)
        steady.update(.good, at: 0.6)
        let changed5 = steady.update(.moveBack, at: 1.1)
        #expect(!changed5)
        #expect(steady.shown == .good)
        let changed6 = steady.update(.moveBack, at: 2.5)
        #expect(changed6)
    }

    @Test("a different new value restarts the wait, and zero hold changes at once")
    func switching() {
        var steady = SteadyValue(DepthAdvice.good, holdSeconds: 1)
        steady.update(.moveBack, at: 0)
        let changed7 = steady.update(.moveCloser, at: 0.9)
        #expect(!changed7)
        let changed8 = steady.update(.moveCloser, at: 1.5)
        #expect(!changed8)
        let changed9 = steady.update(.moveCloser, at: 2.0)
        #expect(changed9)
        var instant = SteadyValue(0, holdSeconds: -5)
        #expect(instant.holdSeconds == 0)
        let changed10 = instant.update(3, at: 0)
        #expect(changed10)
        #expect(instant.shown == 3)
    }
}
