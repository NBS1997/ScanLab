import Foundation
import Testing

@testable import ScanLabCore

@Suite("Thumbnail drawing")
struct ThumbnailRendererTests {
    let renderer = ThumbnailRenderer(size: 64)

    @Test("a cube fills the centre and leaves the corners as background")
    func cube() {
        let image = renderer.render(TestMeshes.cube(size: 0.05))
        #expect(image.width == 64)
        #expect(image.height == 64)
        #expect(image.pixel(column: 32, row: 32) != renderer.background)
        for (column, row) in [(0, 0), (63, 0), (0, 63), (63, 63)] {
            #expect(image.pixel(column: column, row: row) == renderer.background)
        }
    }

    @Test("a three-quarter view shows three sides of a cube in three shades")
    func threeShades() {
        let image = renderer.render(TestMeshes.cube())
        var shades = Set<RGBAColour>()
        for row in 0..<image.height {
            for column in 0..<image.width {
                if let colour = image.pixel(column: column, row: row), colour != renderer.background {
                    shades.insert(colour)
                }
            }
        }
        #expect(shades.count == 3)
    }

    @Test("the picture does not depend on the model's size or position")
    func sizeIndependent() {
        let small = renderer.render(TestMeshes.cube(size: 0.01))
        let moved = TestMeshes.cube(size: 3).transformed(by: .moving(by: Vec3(10, -4, 2)))
        #expect(small == renderer.render(moved))
    }

    @Test("nearer faces hide farther ones whatever order they are drawn in")
    func depthOrder() throws {
        let cube = TestMeshes.cube()
        let reversed = try Mesh(vertices: cube.vertices, triangles: cube.triangles.reversed())
        #expect(renderer.render(cube) == renderer.render(reversed))
    }

    @Test("an empty model gives the placeholder")
    func empty() {
        let image = renderer.render(.empty)
        #expect(image == renderer.placeholder())
        #expect(image.pixel(column: 32, row: 32) == renderer.background)
        #expect(image.pixel(column: 16, row: 32) == renderer.placeholderMark)
    }

    @Test("a model with no size gives the placeholder")
    func flatPoint() throws {
        let point = try Mesh(vertices: [Vec3(1, 1, 1)], triangles: [Triangle(0, 0, 0)])
        #expect(renderer.render(point) == renderer.placeholder())
    }

    @Test("a zero-size picture is empty, and a tiny one has no outline room")
    func tinySizes() {
        #expect(ThumbnailRenderer(size: 0).render(TestMeshes.cube()).bytes.isEmpty)
        #expect(ThumbnailRenderer(size: -5).size == 0)
        let tiny = ThumbnailRenderer(size: 2)
        #expect(tiny.placeholder() == RGBAImage(width: 2, height: 2, filledWith: tiny.background))
    }

    @Test("the default size is 160 pixels")
    func defaultSize() {
        let image = ThumbnailRenderer().render(SampleMeshes.stepBlock(subdivisions: 0))
        #expect(image.width == 160)
        #expect(image.bytes.count == 160 * 160 * 4)
    }
}
