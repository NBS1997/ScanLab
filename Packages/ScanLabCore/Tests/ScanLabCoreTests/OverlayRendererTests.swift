import Testing

@testable import ScanLabCore

@Suite("Overlay pictures")
struct OverlayRendererTests {
    private let red = RGBAColour(red: 255, green: 0, blue: 0)
    private let green = RGBAColour(red: 0, green: 255, blue: 0)
    private let blue = RGBAColour(red: 0, green: 0, blue: 255)
    private let white = RGBAColour(red: 255, green: 255, blue: 255)

    /// A 2 × 3 picture (two columns, three rows) with a different colour in four places.
    private func sample() -> RGBAImage {
        var image = RGBAImage(width: 2, height: 3)
        image.setPixel(column: 0, row: 0, to: red)
        image.setPixel(column: 1, row: 0, to: green)
        image.setPixel(column: 0, row: 2, to: blue)
        image.setPixel(column: 1, row: 2, to: white)
        return image
    }

    @Test("a new picture is filled with one colour")
    func filled() {
        let image = RGBAImage(width: 2, height: 2, filledWith: red)
        #expect(image.bytes == [255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255])
        #expect(RGBAImage(width: -1, height: 3).bytes.isEmpty)
    }

    @Test("pixels outside the picture are ignored")
    func outside() {
        var image = sample()
        let before = image
        image.setPixel(column: 5, row: 0, to: red)
        #expect(image == before)
        #expect(image.pixel(column: 0, row: 3) == nil)
    }

    @Test("turning clockwise puts the top-left corner at the top right")
    func clockwise() {
        let turned = sample().rotated(.clockwise)
        #expect(turned.width == 3)
        #expect(turned.height == 2)
        #expect(turned.pixel(column: 2, row: 0) == red)
        #expect(turned.pixel(column: 2, row: 1) == green)
        #expect(turned.pixel(column: 0, row: 0) == blue)
        #expect(turned.pixel(column: 0, row: 1) == white)
    }

    @Test("turning anticlockwise puts the top-left corner at the bottom left")
    func anticlockwise() {
        let turned = sample().rotated(.anticlockwise)
        #expect(turned.width == 3)
        #expect(turned.pixel(column: 0, row: 1) == red)
        #expect(turned.pixel(column: 0, row: 0) == green)
        #expect(turned.pixel(column: 2, row: 1) == blue)
    }

    @Test("a half turn swaps opposite corners; no turn changes nothing")
    func halfAndNone() {
        let turned = sample().rotated(.half)
        #expect(turned.width == 2)
        #expect(turned.height == 3)
        #expect(turned.pixel(column: 1, row: 2) == red)
        #expect(turned.pixel(column: 0, row: 0) == white)
        #expect(sample().rotated(.none) == sample())
    }

    @Test("four quarter turns bring the picture back")
    func fullCircle() {
        let image = sample()
        let back = image.rotated(.clockwise).rotated(.clockwise).rotated(.half)
        #expect(back == image)
        #expect(image.rotated(.clockwise).rotated(.anticlockwise) == image)
    }

    @Test("the depth picture colours each reading, and gaps grey")
    func depthPicture() throws {
        let frame = try #require(DepthFrame(width: 3, height: 1, depths: [0.2, .nan, 5]))
        let image = OverlayRenderer.depthImage(for: frame)
        #expect(image.width == 3)
        #expect(image.pixel(column: 0, row: 0) == DepthColourMap.ramp.first)
        #expect(image.pixel(column: 1, row: 0) == DepthColourMap.invalidColour)
        #expect(image.pixel(column: 2, row: 0) == DepthColourMap.ramp.last)
    }

    @Test("the confidence picture needs confidence values")
    func confidencePicture() throws {
        let map = ConfidenceColourMap.standard
        let frame = try #require(DepthFrame(width: 2, height: 1, depths: [1, 1], confidence: [0, 2]))
        let image = try #require(OverlayRenderer.confidenceImage(for: frame))
        #expect(image.pixel(column: 0, row: 0) == map.colour(for: .low))
        #expect(image.pixel(column: 1, row: 0) == map.colour(for: .high))
        let bare = try #require(DepthFrame(width: 2, height: 1, depths: [1, 1]))
        #expect(OverlayRenderer.confidenceImage(for: bare) == nil)
    }
}
