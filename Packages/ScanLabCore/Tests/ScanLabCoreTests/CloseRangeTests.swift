import Testing

@testable import ScanLabCore

/// How different two colours look, roughly: the sum of the channel differences.
private func difference(_ first: RGBAColour, _ second: RGBAColour) -> Int {
    abs(Int(first.red) - Int(second.red)) + abs(Int(first.green) - Int(second.green))
        + abs(Int(first.blue) - Int(second.blue))
}

@Suite("Close-range colours")
struct CloseRangeColourTests {
    @Test("a 2 cm step inside a ±5 cm band shows as clearly different colours")
    func twoCentimetreStep() throws {
        // A remote 2 cm high on a sofa arm 80 cm away: arm at 0.80 m, top at 0.78 m.
        let close = try #require(DepthColourMap.closeRange(centredOn: 0.79, halfWidth: 0.05))
        let standard = DepthColourMap.standard
        let closeChange = difference(close.colour(forMetres: 0.78), close.colour(forMetres: 0.80))
        let standardChange = difference(standard.colour(forMetres: 0.78), standard.colour(forMetres: 0.80))
        #expect(closeChange >= 100)
        #expect(standardChange < 20)
        #expect(close.isNarrow)
        #expect(!standard.isNarrow)
    }

    @Test("distances outside the band take the end colours")
    func clampsOutside() throws {
        let close = try #require(DepthColourMap.closeRange(centredOn: 1, halfWidth: 0.05))
        #expect(close.colour(forMetres: 0.5) == DepthColourMap.ramp.first)
        #expect(close.colour(forMetres: 3) == DepthColourMap.ramp.last)
        #expect(close.colour(forMetres: .nan) == DepthColourMap.invalidColour)
    }

    @Test("a zero, negative or impossible band, or no centre reading, gives no map")
    func invalidBand() throws {
        #expect(DepthColourMap.closeRange(centredOn: 1, halfWidth: 0) == nil)
        #expect(DepthColourMap.closeRange(centredOn: 1, halfWidth: -0.05) == nil)
        #expect(DepthColourMap.closeRange(centredOn: 1, halfWidth: .nan) == nil)
        #expect(DepthColourMap.closeRange(centredOn: .nan, halfWidth: 0.05) == nil)
        #expect(DepthColourMap.closeRange(centredOn: 0, halfWidth: 0.05) == nil)
        // Very near: the band's near end stops at zero.
        let near = try #require(DepthColourMap.closeRange(centredOn: 0.03, halfWidth: 0.05))
        #expect(near.nearMetres == 0)
    }

    @Test("the overlay picture uses the close-range colours")
    func overlay() throws {
        let frame = try #require(DepthFrame(width: 2, height: 1, depths: [0.78, 0.80]))
        let close = try #require(DepthColourMap.closeRange(centredOn: 0.79, halfWidth: 0.05))
        let image = OverlayRenderer.depthImage(for: frame, using: close)
        let left = RGBAColour(red: image.bytes[0], green: image.bytes[1], blue: image.bytes[2], alpha: image.bytes[3])
        let right = RGBAColour(red: image.bytes[4], green: image.bytes[5], blue: image.bytes[6], alpha: image.bytes[7])
        #expect(left == close.colour(forMetres: 0.78))
        #expect(right == close.colour(forMetres: 0.80))
        #expect(difference(left, right) >= 100)
    }
}

@Suite("Close-range band")
struct CloseRangeBandTests {
    @Test("the band centres on the first reading and ignores small wobbles")
    func followsWithHysteresis() throws {
        var band = CloseRangeBand()
        #expect(band.colourMap == nil)
        let changed1 = band.follow(0.80)
        #expect(changed1)
        #expect(band.centre == 0.80)
        // 2 cm is within half of ±5 cm: no move.
        let changed2 = band.follow(0.82)
        #expect(!changed2)
        #expect(band.centre == 0.80)
        // 3 cm is beyond it: the band follows.
        let changed3 = band.follow(0.83)
        #expect(changed3)
        #expect(band.centre == 0.83)
        let map = try #require(band.colourMap)
        #expect(abs(map.nearMetres - 0.78) < 1e-6)
        #expect(abs(map.farMetres - 0.88) < 1e-6)
    }

    @Test("missing readings leave the band where it was")
    func missingReadings() {
        var band = CloseRangeBand()
        band.follow(1.2)
        let changed4 = band.follow(nil)
        #expect(!changed4)
        let changed5 = band.follow(.nan)
        #expect(!changed5)
        let changed6 = band.follow(0)
        #expect(!changed6)
        #expect(band.centre == 1.2)
    }

    @Test("the width can be changed, but only to a positive number")
    func widths() {
        var band = CloseRangeBand(halfWidth: -1)
        #expect(band.halfWidth == CloseRangeBand.defaultHalfWidth)
        band.setHalfWidth(0.02)
        #expect(band.halfWidth == 0.02)
        band.setHalfWidth(0)
        band.setHalfWidth(.infinity)
        #expect(band.halfWidth == 0.02)
        #expect(CloseRangeBand.halfWidthChoices.contains(CloseRangeBand.defaultHalfWidth))
    }

    @Test("labels read as centimetres")
    func labels() {
        #expect(CloseRangeBand.label(halfWidth: 0.05) == "±5 cm")
        #expect(CloseRangeBand.label(halfWidth: 0.10) == "±10 cm")
        #expect(CloseRangeBand.spokenLabel(halfWidth: 0.02) == "plus or minus 2 centimetres")
        #expect(CloseRangeBand.spokenLabel(halfWidth: 0.01) == "plus or minus 1 centimetre")
    }
}
