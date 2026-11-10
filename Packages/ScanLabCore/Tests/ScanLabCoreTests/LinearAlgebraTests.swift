import Foundation
import Testing

@testable import ScanLabCore

@Suite("Accuracy maths")
struct LinearAlgebraTests {
    @Test("a quarter turn about z sends x to y")
    func quarterTurn() {
        let turn = Matrix3.rotation(axis: Vec3(0, 0, 2), angle: .pi / 2)
        #expect(isClose(turn * Vec3(1, 0, 0), Vec3(0, 1, 0), tolerance: 1e-12))
        #expect(isClose(turn.determinant, 1, tolerance: 1e-12))
        #expect(isClose(turn.angle(to: .identity), .pi / 2, tolerance: 1e-12))
    }

    @Test("no axis or no angle is no turn")
    func noTurn() {
        #expect(Matrix3.rotation(axis: .zero, angle: 1) == .identity)
        #expect(Matrix3.rotation(vector: .zero) == .identity)
    }

    @Test("a transform followed by its inverse leaves points where they were")
    func inverse() {
        let transform = AccuracyFixtures.misplacement
        let point = Vec3(0.01, -0.02, 0.5)
        let back = transform.followed(by: transform.rigidInverse)
        #expect(isClose(back.apply(to: point), point, tolerance: 1e-12))
        #expect(isClose(transform.followed(by: .identity).apply(to: point), transform.apply(to: point)))
    }

    @Test("there are 24 axis arrangements, all real turns and all different")
    func arrangements() {
        let all = Matrix3.axisArrangements
        #expect(all.count == 24)
        #expect(all.allSatisfy { isClose($0.determinant, 1) })
        for (index, first) in all.enumerated() {
            #expect(!all[(index + 1)...].contains(first))
        }
    }

    @Test("principal axes of a stretched cloud point along its stretch")
    func principalAxes() {
        // Variance 9 along x, 4 along z, 1 along y.
        let spread = Matrix3(xRow: Vec3(9, 0, 0), yRow: Vec3(0, 1, 0), zRow: Vec3(0, 0, 4))
        let result = LinearAlgebra.principalAxes(of: spread)
        #expect(isClose(result.strengths, Vec3(9, 4, 1), tolerance: 1e-12))
        let columns = result.axes.columns
        #expect(isClose(abs(columns[0].x), 1, tolerance: 1e-12))
        #expect(isClose(abs(columns[1].z), 1, tolerance: 1e-12))
        #expect(isClose(result.axes.determinant, 1, tolerance: 1e-12))
    }

    @Test("principal axes of a turned matrix are found by Jacobi's method")
    func principalAxesTurned() {
        let turn = Matrix3.rotation(axis: Vec3(1, 1, 0), angle: 0.7)
        let spread = turn * Matrix3(xRow: Vec3(5, 0, 0), yRow: Vec3(0, 3, 0), zRow: Vec3(0, 0, 1)) * turn.transposed
        let result = LinearAlgebra.principalAxes(of: spread)
        #expect(isClose(result.strengths, Vec3(5, 3, 1), tolerance: 1e-9))
        for (column, strength) in zip(result.axes.columns, [5.0, 3, 1]) {
            #expect(isClose(spread * column, column * strength, tolerance: 1e-9))
        }
    }

    @Test("covariance and centroid of known points")
    func covariance() {
        let points = [Vec3(1, 0, 0), Vec3(-1, 0, 0), Vec3(0, 2, 0), Vec3(0, -2, 0)]
        let centre = LinearAlgebra.centroid(points)
        #expect(centre == .zero)
        let spread = LinearAlgebra.covariance(points, about: centre)
        #expect(isClose(spread.xRow.x, 0.5))
        #expect(isClose(spread.yRow.y, 2))
        #expect(LinearAlgebra.centroid([]) == .zero)
    }

    @Test("solving equations, including one needing a row swap")
    func solve() throws {
        let answer = try #require(LinearAlgebra.solve([0, 2, 1, 1], [4, 3]))
        #expect(isClose(answer[0], 1))
        #expect(isClose(answer[1], 2))
    }

    @Test("equations with no single answer give nil")
    func solveSingular() {
        #expect(LinearAlgebra.solve([1, 2, 2, 4], [1, 2]) == nil)
        #expect(LinearAlgebra.solve([1, 2, 3], [1, 2]) == nil)
        #expect(LinearAlgebra.solve([], []) == nil)
    }

    @Test("components by axis number")
    func components() {
        let point = Vec3(1, 2, 3)
        #expect([0, 1, 2].map(point.component) == [1, 2, 3])
    }
}
