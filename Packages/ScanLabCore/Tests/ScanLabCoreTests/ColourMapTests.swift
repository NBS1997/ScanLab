import Testing

@testable import ScanLabCore

@Suite("Depth colour map")
struct DepthColourMapTests {
    private let map = DepthColourMap.standard

    @Test("near is warm and far is cool")
    func nearWarmFarCool() {
        let near = map.colour(forMetres: 0.2)
        let far = map.colour(forMetres: 5)
        #expect(near == DepthColourMap.ramp.first)
        #expect(far == DepthColourMap.ramp.last)
        #expect(near.red > near.blue)
        #expect(far.blue > far.red)
    }

    @Test("distances outside the range take the colour of the nearer end")
    func clamping() {
        #expect(map.colour(forMetres: 0.05) == map.colour(forMetres: 0.2))
        #expect(map.colour(forMetres: 12) == map.colour(forMetres: 5))
        #expect(map.position(forMetres: 0.05) == 0)
        #expect(map.position(forMetres: 12) == 1)
    }

    @Test("missing readings use the invalid colour")
    func invalidReadings() {
        for metres: Float in [.nan, 0, -1, .infinity] {
            #expect(map.colour(forMetres: metres) == DepthColourMap.invalidColour)
            #expect(map.position(forMetres: metres) == nil)
        }
    }

    @Test("colours change smoothly between ramp stops")
    func blending() throws {
        // 2.5 m on a 0–5 m map is halfway along a six-colour ramp: midway between the
        // third and fourth colours.
        let custom = try #require(DepthColourMap(nearMetres: 0, farMetres: 5))
        let ramp = DepthColourMap.ramp
        #expect(custom.colour(forMetres: 2.5) == ramp[2].blended(towards: ramp[3], by: 0.5))
        let firstHalfway = ramp[0].blended(towards: ramp[1], by: 0.5)
        #expect(firstHalfway == RGBAColour(red: 233, green: 90, blue: 35))
    }

    @Test("a range can be chosen, and bad ranges are refused")
    func customRange() {
        let custom = DepthColourMap(nearMetres: 1, farMetres: 2)
        #expect(custom?.position(forMetres: 1.5) == 0.5)
        #expect(DepthColourMap(nearMetres: 2, farMetres: 1) == nil)
        #expect(DepthColourMap(nearMetres: 1, farMetres: 1) == nil)
        #expect(DepthColourMap(nearMetres: -1, farMetres: 1) == nil)
        #expect(DepthColourMap(nearMetres: 0, farMetres: .nan) == nil)
    }

    @Test("the legend runs from near to far with matching colours")
    func legend() {
        let stops = map.legendStops(count: 3)
        let expected: [Float] = [0.2, 2.6, 5]
        #expect(stops.count == 3)
        for (stop, metres) in zip(stops, expected) {
            #expect(abs(stop.metres - metres) < 0.000_1)
        }
        #expect(stops.first?.colour == DepthColourMap.ramp.first)
        #expect(stops.last?.colour == DepthColourMap.ramp.last)
        #expect(map.legendStops(count: 0).count == 2)
        #expect(map.legendStops().count == 5)
    }
}

@Suite("Confidence colour map")
struct ConfidenceColourMapTests {
    private let map = ConfidenceColourMap.standard

    @Test("each level has its own colour: low red, high green")
    func levels() {
        let colours = ConfidenceLevel.allCases.map { map.colour(for: $0) }
        #expect(Set(colours).count == 3)
        #expect(map.colour(for: .low).red > map.colour(for: .low).green)
        #expect(map.colour(for: .high).green > map.colour(for: .high).red)
    }

    @Test("raw values map to levels; unknown values are invalid")
    func rawValues() {
        #expect(map.colour(forRawValue: 0) == map.colour(for: .low))
        #expect(map.colour(forRawValue: 1) == map.colour(for: .medium))
        #expect(map.colour(forRawValue: 2) == map.colour(for: .high))
        #expect(map.colour(forRawValue: 3) == DepthColourMap.invalidColour)
        #expect(map.colour(forRawValue: 255) == DepthColourMap.invalidColour)
    }
}

@Suite("Colour blending")
struct ColourBlendTests {
    private let black = RGBAColour(red: 0, green: 0, blue: 0, alpha: 0)
    private let white = RGBAColour(red: 255, green: 255, blue: 255)

    @Test("blending goes from one colour to the other")
    func ends() {
        #expect(black.blended(towards: white, by: 0) == black)
        #expect(black.blended(towards: white, by: 1) == white)
        #expect(black.blended(towards: white, by: 0.5) == RGBAColour(red: 128, green: 128, blue: 128, alpha: 128))
    }

    @Test("amounts outside 0–1 are clamped")
    func clamped() {
        #expect(black.blended(towards: white, by: -3) == black)
        #expect(black.blended(towards: white, by: 9) == white)
    }
}
