import Foundation

/// A 3 × 3 matrix stored as its three rows. The accuracy code uses it for turns
/// (rotations) and for the spread of a cloud of points (its covariance).
struct Matrix3: Equatable, Sendable {
    var xRow: Vec3
    var yRow: Vec3
    var zRow: Vec3

    static let identity = Matrix3(xRow: Vec3(1, 0, 0), yRow: Vec3(0, 1, 0), zRow: Vec3(0, 0, 1))

    static func * (lhs: Matrix3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.xRow.dot(rhs), lhs.yRow.dot(rhs), lhs.zRow.dot(rhs))
    }

    static func * (lhs: Matrix3, rhs: Matrix3) -> Matrix3 {
        // Each row of the answer is a row of the left matrix dotted with each column
        // of the right one; the right matrix's columns are its transpose's rows.
        let columns = rhs.transposed
        func times(_ row: Vec3) -> Vec3 {
            Vec3(row.dot(columns.xRow), row.dot(columns.yRow), row.dot(columns.zRow))
        }
        return Matrix3(xRow: times(lhs.xRow), yRow: times(lhs.yRow), zRow: times(lhs.zRow))
    }

    /// Rows become columns. For a rotation this is the reverse turn.
    var transposed: Matrix3 {
        Matrix3(columns: xRow, yRow, zRow)
    }

    var determinant: Double {
        xRow.dot(yRow.cross(zRow))
    }

    var trace: Double {
        xRow.x + yRow.y + zRow.z
    }

    /// The three columns, in order.
    var columns: [Vec3] {
        let flipped = transposed
        return [flipped.xRow, flipped.yRow, flipped.zRow]
    }

    /// The size of the turn, in radians, needed to get from this rotation to `other`.
    func angle(to other: Matrix3) -> Double {
        let relative = transposed * other
        let cosine = min(1, max(-1, (relative.trace - 1) / 2))
        return acos(cosine)
    }
}

extension Matrix3 {
    /// A matrix whose columns are the three given directions.
    init(columns first: Vec3, _ second: Vec3, _ third: Vec3) {
        self.init(
            xRow: Vec3(first.x, second.x, third.x),
            yRow: Vec3(first.y, second.y, third.y),
            zRow: Vec3(first.z, second.z, third.z))
    }

    /// A turn of `angle` radians about `axis`, by Rodrigues' formula: the part of a
    /// point along the axis stays put, and the rest swings round the axis like a door.
    static func rotation(axis: Vec3, angle: Double) -> Matrix3 {
        let unit = axis.normalised
        guard unit != .zero, angle != 0 else { return .identity }
        let cosine = cos(angle)
        let sine = sin(angle)
        let rest = 1 - cosine
        return Matrix3(
            xRow: Vec3(
                cosine + rest * unit.x * unit.x, rest * unit.x * unit.y - sine * unit.z,
                rest * unit.x * unit.z + sine * unit.y),
            yRow: Vec3(
                rest * unit.y * unit.x + sine * unit.z, cosine + rest * unit.y * unit.y,
                rest * unit.y * unit.z - sine * unit.x),
            zRow: Vec3(
                rest * unit.z * unit.x - sine * unit.y, rest * unit.z * unit.y + sine * unit.x,
                cosine + rest * unit.z * unit.z))
    }

    /// A turn given as one vector: its direction is the axis and its length the angle
    /// in radians. This is how alignment describes each small correction.
    static func rotation(vector: Vec3) -> Matrix3 {
        rotation(axis: vector, angle: vector.length)
    }

    /// The 24 ways of lining up three axes with three axes without mirroring: every
    /// order of the axes, each pointing either way, keeping only the arrangements that
    /// are real turns (determinant +1) rather than reflections.
    static let axisArrangements: [Matrix3] = {
        let units = [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)]
        let orders = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
        var arrangements: [Matrix3] = []
        for order in orders {
            for signs in 0..<8 {
                let first = units[order[0]] * (signs & 1 == 0 ? 1 : -1)
                let second = units[order[1]] * (signs & 2 == 0 ? 1 : -1)
                let third = units[order[2]] * (signs & 4 == 0 ? 1 : -1)
                let candidate = Matrix3(columns: first, second, third)
                if candidate.determinant > 0 {
                    arrangements.append(candidate)
                }
            }
        }
        return arrangements
    }()
}

extension Vec3 {
    static func += (lhs: inout Vec3, rhs: Vec3) {
        lhs = lhs + rhs
    }

    /// The part along axis 0 (x), 1 (y) or 2 (z).
    func component(_ axis: Int) -> Double {
        switch axis {
        case 0: x
        case 1: y
        default: z
        }
    }
}

extension Transform {
    /// A turn followed by a move.
    init(rotation: Matrix3, translation: Vec3) {
        self.init(xRow: rotation.xRow, yRow: rotation.yRow, zRow: rotation.zRow, translation: translation)
    }

    /// The turning part, without the move.
    var rotation: Matrix3 {
        Matrix3(xRow: xRow, yRow: yRow, zRow: zRow)
    }

    /// This transform, then `next`.
    func followed(by next: Transform) -> Transform {
        Transform(rotation: next.rotation * rotation, translation: next.rotation * translation + next.translation)
    }

    /// The transform that undoes this one. Only right for turns and moves (no
    /// resizing), which is all alignment produces: a turn is undone by its transpose.
    var rigidInverse: Transform {
        let back = rotation.transposed
        return Transform(rotation: back, translation: -(back * translation))
    }
}

/// Small numerical routines used by alignment.
enum LinearAlgebra {
    /// The average of the points, or zero when there are none.
    static func centroid(_ points: [Vec3]) -> Vec3 {
        guard !points.isEmpty else { return .zero }
        return points.reduce(Vec3.zero, +) / Double(points.count)
    }

    /// How the points spread about `centre`: entry (row, column) is the average of
    /// the product of their offsets along those two axes.
    static func covariance(_ points: [Vec3], about centre: Vec3) -> Matrix3 {
        var xRow = Vec3.zero
        var yRow = Vec3.zero
        var zRow = Vec3.zero
        for point in points {
            let offset = point - centre
            xRow += offset * offset.x
            yRow += offset * offset.y
            zRow += offset * offset.z
        }
        let count = Double(max(points.count, 1))
        return Matrix3(xRow: xRow / count, yRow: yRow / count, zRow: zRow / count)
    }

    /// The main directions of a symmetric matrix (its eigenvectors) and how strong each
    /// is (its eigenvalues), strongest first, by Jacobi's method: repeatedly turn the
    /// matrix a little so one off-diagonal entry becomes zero, until all are.
    ///
    /// The directions are returned as the columns of a turn (determinant +1), so they
    /// can be used directly to line one shape's axes up with another's.
    static func principalAxes(of symmetric: Matrix3) -> (axes: Matrix3, strengths: Vec3) {
        var matrix = [symmetric.xRow, symmetric.yRow, symmetric.zRow].map { [$0.x, $0.y, $0.z] }
        var vectors = [[1.0, 0, 0], [0, 1.0, 0], [0, 0, 1.0]]
        for _ in 0..<50 {
            let offDiagonal = abs(matrix[0][1]) + abs(matrix[0][2]) + abs(matrix[1][2])
            if offDiagonal < 1e-30 { break }
            for (first, second) in [(0, 1), (0, 2), (1, 2)] {
                jacobiTurn(&matrix, &vectors, first, second)
            }
        }
        var order = [0, 1, 2]
        order.sort { matrix[$0][$0] > matrix[$1][$1] }
        let columns = order.map { Vec3(vectors[0][$0], vectors[1][$0], vectors[2][$0]) }
        let first = columns[0].normalised
        let second = columns[1].normalised
        // Rebuild the third from the first two so the result never mirrors.
        let axes = Matrix3(columns: first, second, first.cross(second))
        let strengths = Vec3(matrix[order[0]][order[0]], matrix[order[1]][order[1]], matrix[order[2]][order[2]])
        return (axes, strengths)
    }

    /// One Jacobi step: a turn in the plane of axes `first` and `second` chosen so the
    /// matrix entry linking them becomes zero (Numerical Recipes, section 11.1).
    private static func jacobiTurn(
        _ matrix: inout [[Double]], _ vectors: inout [[Double]], _ first: Int, _ second: Int
    ) {
        let link = matrix[first][second]
        guard abs(link) > 1e-300 else { return }
        let theta = (matrix[second][second] - matrix[first][first]) / (2 * link)
        let sign: Double = theta >= 0 ? 1 : -1
        let tangent = sign / (abs(theta) + (theta * theta + 1).squareRoot())
        let cosine = 1 / (tangent * tangent + 1).squareRoot()
        let sine = tangent * cosine
        var turn = [[1.0, 0, 0], [0, 1.0, 0], [0, 0, 1.0]]
        turn[first][first] = cosine
        turn[second][second] = cosine
        turn[first][second] = sine
        turn[second][first] = -sine
        matrix = multiply(multiply(transpose(turn), matrix), turn)
        vectors = multiply(vectors, turn)
    }

    private static func multiply(_ left: [[Double]], _ right: [[Double]]) -> [[Double]] {
        (0..<3).map { row in
            (0..<3).map { column in
                (0..<3).reduce(0.0) { $0 + left[row][$1] * right[$1][column] }
            }
        }
    }

    private static func transpose(_ matrix: [[Double]]) -> [[Double]] {
        (0..<3).map { row in (0..<3).map { matrix[$0][row] } }
    }

    /// Solves `matrix × answer = right` for `answer` by Gaussian elimination, swapping
    /// rows so the largest available number is always used to divide by (partial
    /// pivoting, which keeps rounding errors small). `matrix` is square, stored row by
    /// row in one flat list. Returns `nil` when the equations have no single answer.
    static func solve(_ matrix: [Double], _ right: [Double]) -> [Double]? {
        let size = right.count
        guard size > 0, matrix.count == size * size else { return nil }
        var grid = matrix
        var values = right
        for pivot in 0..<size {
            guard eliminate(below: pivot, size: size, grid: &grid, values: &values) else { return nil }
        }
        return backSubstitute(size: size, grid: grid, values: values)
    }

    /// Swaps the row with the largest entry in column `pivot` into place, then
    /// subtracts multiples of it from the rows below so their entries in that column
    /// become zero. `false` when the whole column is zero.
    private static func eliminate(below pivot: Int, size: Int, grid: inout [Double], values: inout [Double]) -> Bool {
        var best = pivot
        for row in (pivot + 1)..<size where abs(grid[row * size + pivot]) > abs(grid[best * size + pivot]) {
            best = row
        }
        guard abs(grid[best * size + pivot]) > 1e-300 else { return false }
        if best != pivot {
            for column in 0..<size {
                grid.swapAt(pivot * size + column, best * size + column)
            }
            values.swapAt(pivot, best)
        }
        for row in (pivot + 1)..<size {
            let factor = grid[row * size + pivot] / grid[pivot * size + pivot]
            guard factor != 0 else { continue }
            for column in pivot..<size {
                grid[row * size + column] -= factor * grid[pivot * size + column]
            }
            values[row] -= factor * values[pivot]
        }
        return true
    }

    /// Solves the triangle of equations left by elimination, from the last unknown up.
    private static func backSubstitute(size: Int, grid: [Double], values: [Double]) -> [Double]? {
        var answer = [Double](repeating: 0, count: size)
        for row in stride(from: size - 1, through: 0, by: -1) {
            var total = values[row]
            for column in (row + 1)..<size {
                total -= grid[row * size + column] * answer[column]
            }
            answer[row] = total / grid[row * size + row]
        }
        return answer.allSatisfy(\.isFinite) ? answer : nil
    }
}
