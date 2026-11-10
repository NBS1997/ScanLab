import Foundation
import Testing

@testable import ScanLabCore

@Suite("Vectors, boxes and transforms")
struct VectorTests {
    @Test("arithmetic works part by part")
    func arithmetic() {
        let first = Vec3(1, 2, 3)
        let second = Vec3(4, 5, 6)
        #expect(first + second == Vec3(5, 7, 9))
        #expect(second - first == Vec3(3, 3, 3))
        #expect(-first == Vec3(-1, -2, -3))
        #expect(first * 2 == Vec3(2, 4, 6))
        #expect(2 * first == Vec3(2, 4, 6))
        #expect(second / 2 == Vec3(2, 2.5, 3))
        #expect(first.dot(second) == 32)
    }

    @Test("cross product follows the right-hand rule")
    func cross() {
        #expect(Vec3(1, 0, 0).cross(Vec3(0, 1, 0)) == Vec3(0, 0, 1))
        #expect(Vec3(0, 1, 0).cross(Vec3(1, 0, 0)) == Vec3(0, 0, -1))
    }

    @Test("length, distance and normalising")
    func lengths() {
        #expect(Vec3(3, 4, 0).length == 5)
        #expect(Vec3(0, 0, 0).distance(to: Vec3(0, 3, 4)) == 5)
        #expect(Vec3(0, 0, 2).normalised == Vec3(0, 0, 1))
    }

    @Test("a zero vector normalises to zero rather than to not-a-number")
    func normaliseZero() {
        #expect(Vec3.zero.normalised == .zero)
    }

    @Test("infinite or not-a-number parts are detected")
    func finiteness() {
        #expect(Vec3(1, 2, 3).isFinite)
        #expect(!Vec3(.infinity, 0, 0).isFinite)
        #expect(!Vec3(0, .nan, 0).isFinite)
    }

    @Test("a box encloses its points and reports its size and centre")
    func boxEnclosing() throws {
        let box = try #require(Box(enclosing: [Vec3(1, 5, -2), Vec3(-1, 2, 4), Vec3(0, 3, 0)]))
        #expect(box.minimum == Vec3(-1, 2, -2))
        #expect(box.maximum == Vec3(1, 5, 4))
        #expect(box.size == Vec3(2, 3, 6))
        #expect(box.centre == Vec3(0, 3.5, 1))
        #expect(box.diagonal == 7)
    }

    @Test("a box of no points does not exist")
    func emptyBox() {
        #expect(Box(enclosing: [Vec3]()) == nil)
    }

    @Test("containment respects the tolerance")
    func boxContains() {
        let box = Box(minimum: .zero, maximum: Vec3(1, 1, 1))
        #expect(box.contains(Vec3(0.5, 0.5, 0.5)))
        #expect(box.contains(Vec3(1, 1, 1)))
        #expect(!box.contains(Vec3(1.01, 0.5, 0.5)))
        #expect(box.contains(Vec3(1.01, 0.5, 0.5), tolerance: 0.02))
    }

    @Test("scaling, moving and their determinants")
    func transforms() {
        #expect(Transform.identity.apply(to: Vec3(1, 2, 3)) == Vec3(1, 2, 3))
        #expect(Transform.scaling(by: 1000).apply(to: Vec3(0.25, 0, 0.5)) == Vec3(250, 0, 500))
        #expect(Transform.moving(by: Vec3(1, 1, 1)).apply(to: Vec3(1, 2, 3)) == Vec3(2, 3, 4))
        #expect(Transform.scaling(by: 2).determinant == 8)
        #expect(Transform.scaling(by: -1).determinant == -1)
    }
}
