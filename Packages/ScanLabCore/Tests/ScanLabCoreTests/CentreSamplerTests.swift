import Testing

@testable import ScanLabCore

@Suite("Centre sampler")
struct CentreSamplerTests {
    /// A frame where every pixel reads `metres`, with optional confidence.
    private func uniformFrame(
        width: Int = 9, height: Int = 7, metres: Float, confidence: UInt8? = nil
    ) throws -> DepthFrame {
        let count = width * height
        let levels = confidence.map { [UInt8](repeating: $0, count: count) } ?? []
        return try #require(
            DepthFrame(
                width: width, height: height, depths: [Float](repeating: metres, count: count), confidence: levels))
    }

    @Test("a flat wall reads its distance")
    func flatWall() throws {
        let frame = try uniformFrame(metres: 1.0, confidence: 2)
        #expect(CentreSampler.distance(in: frame) == 1.0)
    }

    @Test("the median ignores a few stray readings")
    func medianIgnoresOutliers() throws {
        // A 3 × 3 frame: eight readings at 1 m and one wild one at 4 m.
        let frame = try #require(DepthFrame(width: 3, height: 3, depths: [1, 1, 1, 1, 4, 1, 1, 1, 1]))
        #expect(CentreSampler.distance(in: frame, window: 3, minimumConfidence: nil) == 1)
    }

    @Test("NaN and zero pixels are skipped")
    func skipsMissing() throws {
        let frame = try #require(
            DepthFrame(width: 3, height: 1, depths: [.nan, 0.8, 0], confidence: []))
        #expect(CentreSampler.distance(in: frame, window: 3) == 0.8)
    }

    @Test("an all-invalid frame gives no reading")
    func allInvalid() throws {
        #expect(CentreSampler.distance(in: try uniformFrame(metres: .nan)) == nil)
        #expect(CentreSampler.distance(in: try uniformFrame(metres: 0)) == nil)
    }

    @Test("low-confidence pixels are skipped unless asked for")
    func confidenceFilter() throws {
        let frame = try uniformFrame(metres: 2, confidence: 0)
        #expect(CentreSampler.distance(in: frame) == nil)
        #expect(CentreSampler.distance(in: frame, minimumConfidence: .low) == 2)
        #expect(CentreSampler.distance(in: frame, minimumConfidence: nil) == 2)
    }

    @Test("only the centre square is used")
    func centreOnly() throws {
        // 5 × 1 frame: the centre pixel is 3 m, the edges are 9 m.
        let frame = try #require(DepthFrame(width: 5, height: 1, depths: [9, 9, 3, 9, 9]))
        #expect(CentreSampler.distance(in: frame, window: 1) == 3)
    }

    @Test("a window larger than the frame is clamped; a zero window uses one pixel")
    func windowClamping() throws {
        let frame = try #require(DepthFrame(width: 2, height: 2, depths: [1, 2, 3, 4]))
        #expect(CentreSampler.distance(in: frame, window: 50) == 2.5)
        #expect(CentreSampler.distance(in: frame, window: 0) != nil)
    }

    @Test("median of an even count is the midpoint")
    func evenMedian() {
        #expect(CentreSampler.median(of: [4, 1, 3, 2]) == 2.5)
        #expect(CentreSampler.median(of: [5]) == 5)
        #expect(CentreSampler.median(of: []) == nil)
    }
}
