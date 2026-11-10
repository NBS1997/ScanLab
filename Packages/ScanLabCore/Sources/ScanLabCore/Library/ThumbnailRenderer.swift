import Foundation

/// Draws a small shaded picture of a model for the library list (FR-6.1).
///
/// How it works, in plain terms:
/// 1. **Viewpoint.** The model is looked at from in front, to the right and above (a
///    "three-quarter" view), so three sides of a box show at once. Models are taken to
///    have z pointing up, as the sample and exports do.
/// 2. **Projection.** Each corner is moved onto the picture by measuring how far it lies
///    along the picture's "right" and "up" directions. This is an orthographic
///    projection: no perspective, so the picture is simple and nothing is distorted.
/// 3. **Hidden surfaces.** Every pixel remembers how near the closest face drawn on it
///    so far was (a "z-buffer"). A face only paints a pixel if it is nearer, so the
///    back of the model never shows through the front.
/// 4. **Shading.** Each face is lit by how directly it faces a light above and to the
///    left of the viewer (Lambert shading), so faces at different angles get different
///    shades and the shape reads as 3D.
///
/// Pure Swift with no graphics framework, so it is tested on the build machine.
public struct ThumbnailRenderer: Sendable {
    /// Width and height of the picture in pixels.
    public var size: Int
    public var background: RGBAColour
    /// The colour of a face lit straight on.
    public var surface: RGBAColour
    /// The colour of the outline drawn when there is no model to show.
    public var placeholderMark: RGBAColour

    public init(
        size: Int = 160,
        background: RGBAColour = RGBAColour(red: 44, green: 52, blue: 64),
        surface: RGBAColour = RGBAColour(red: 214, green: 222, blue: 235),
        placeholderMark: RGBAColour = RGBAColour(red: 120, green: 130, blue: 145)
    ) {
        self.size = max(size, 0)
        self.background = background
        self.surface = surface
        self.placeholderMark = placeholderMark
    }

    /// The fraction of the picture's half-width the model may fill, leaving a margin.
    static let fillFraction = 0.85
    /// How bright a face pointing away from the light still is, so no face is black.
    static let ambient = 0.3

    /// The picture's three directions in model space. `towardsViewer` points from the
    /// model to the eye; `right` and `upward` are the picture's right and up.
    struct ViewAxes {
        let towardsViewer: Vec3
        let right: Vec3
        let upward: Vec3
        let light: Vec3

        static let threeQuarter: ViewAxes = {
            let towardsViewer = Vec3(1, -1.4, 1).normalised
            let right = Vec3(0, 0, 1).cross(towardsViewer).normalised
            let upward = towardsViewer.cross(right).normalised
            let light = (towardsViewer + upward * 0.8 - right * 0.5).normalised
            return ViewAxes(towardsViewer: towardsViewer, right: right, upward: upward, light: light)
        }()
    }

    /// The model's picture, or the placeholder when it has no faces or no size.
    public func render(_ mesh: Mesh) -> RGBAImage {
        guard size > 0, let box = mesh.boundingBox, box.diagonal > 0 else { return placeholder() }
        let axes = ViewAxes.threeQuarter
        let scale = Double(size) / 2 * Self.fillFraction / (box.diagonal / 2)
        let centre = box.centre
        let half = Double(size) / 2
        // Where each vertex lands on the picture, and how near the viewer it is.
        let projected = mesh.vertices.map { vertex -> ScreenPoint in
            let offset = vertex - centre
            return ScreenPoint(
                column: half + offset.dot(axes.right) * scale,
                row: half - offset.dot(axes.upward) * scale,
                depth: offset.dot(axes.towardsViewer))
        }
        var canvas = Canvas(size: size, background: background)
        for (index, triangle) in mesh.triangles.enumerated() {
            let normal = mesh.faceNormal(index)
            // Scanned models do not always have every face turned outwards, so a face is
            // lit the same from either side.
            let brightness = Self.ambient + (1 - Self.ambient) * abs(normal.dot(axes.light))
            let shaded = RGBAColour(red: 0, green: 0, blue: 0).blended(towards: surface, by: Float(brightness))
            canvas.fill(projected[triangle.a], projected[triangle.b], projected[triangle.c], colour: shaded)
        }
        return canvas.image
    }

    /// Shown for a model with nothing to draw: the background with a square outline,
    /// so the row still looks deliberate.
    public func placeholder() -> RGBAImage {
        var image = RGBAImage(width: size, height: size, filledWith: background)
        // Below 8 pixels there is no room for a recognisable outline.
        guard size >= 8 else { return image }
        let low = size / 4
        let high = size - 1 - size / 4
        for position in low...high {
            for thickness in 0..<2 {
                image.setPixel(column: position, row: low + thickness, to: placeholderMark)
                image.setPixel(column: position, row: high - thickness, to: placeholderMark)
                image.setPixel(column: low + thickness, row: position, to: placeholderMark)
                image.setPixel(column: high - thickness, row: position, to: placeholderMark)
            }
        }
        return image
    }
}

/// A vertex after projection: where it falls on the picture and how near it is.
struct ScreenPoint {
    var column: Double
    var row: Double
    var depth: Double
}

/// The picture being drawn, with its z-buffer.
private struct Canvas {
    var image: RGBAImage
    /// For each pixel, the nearness of the face painted there; larger is nearer.
    private var nearest: [Double]
    private let size: Int

    init(size: Int, background: RGBAColour) {
        self.size = size
        image = RGBAImage(width: size, height: size, filledWith: background)
        nearest = [Double](repeating: -.infinity, count: size * size)
    }

    /// Paints every pixel whose centre lies inside the triangle and where the triangle
    /// is nearer than anything already painted.
    ///
    /// A pixel is inside when it is on the same side of all three edges. The "edge
    /// function" below measures which side of an edge a point is on (and, divided by
    /// the triangle's doubled area, how far along towards the opposite corner), which
    /// also gives the weights for blending the three corners' depths.
    mutating func fill(_ first: ScreenPoint, _ second: ScreenPoint, _ third: ScreenPoint, colour: RGBAColour) {
        let area = edge(first, second, third.column, third.row)
        guard area != 0, area.isFinite else { return }
        let minColumn = max(0, Int(min(first.column, second.column, third.column).rounded(.down)))
        let maxColumn = min(size - 1, Int(max(first.column, second.column, third.column).rounded(.up)))
        let minRow = max(0, Int(min(first.row, second.row, third.row).rounded(.down)))
        let maxRow = min(size - 1, Int(max(first.row, second.row, third.row).rounded(.up)))
        guard minColumn <= maxColumn, minRow <= maxRow else { return }
        for row in minRow...maxRow {
            let pixelRow = Double(row) + 0.5
            for column in minColumn...maxColumn {
                let pixelColumn = Double(column) + 0.5
                let weightFirst = edge(second, third, pixelColumn, pixelRow) / area
                let weightSecond = edge(third, first, pixelColumn, pixelRow) / area
                let weightThird = 1 - weightFirst - weightSecond
                guard weightFirst >= 0, weightSecond >= 0, weightThird >= 0 else { continue }
                let depth = weightFirst * first.depth + weightSecond * second.depth + weightThird * third.depth
                let index = row * size + column
                if depth > nearest[index] {
                    nearest[index] = depth
                    image.setPixel(column: column, row: row, to: colour)
                }
            }
        }
    }

    /// Twice the signed area of the triangle (start, end, point): positive on one side
    /// of the line from `start` to `end`, negative on the other.
    private func edge(_ start: ScreenPoint, _ end: ScreenPoint, _ column: Double, _ row: Double) -> Double {
        (end.column - start.column) * (row - start.row) - (end.row - start.row) * (column - start.column)
    }
}
