import Foundation

/// Finds the box around the part the owner tapped, from one depth picture and, when
/// Vision found one, the tapped object's outline (SB-2 to SB-5, ADR-030).
///
/// Steps, in plain terms:
/// 1. Turn every usable depth reading into a point in the world.
/// 2. Find the tapped point: the reading under the finger, or the nearest one close by.
/// 3. Split the points into "subject" (inside Vision's outline, or, without one, within
///    15 cm sideways of the tapped point) and "the rest".
/// 4. Find the surface the subject stands on: among the rest, near the tap and lower
///    than it, the most common height (heights are counted in 5 mm steps).
/// 5. Throw away subject points that are really the surface, then fit the box to what
///    is left, ignoring the most extreme 2% on each side so a few stray readings cannot
///    stretch it.
public enum SubjectFinder {
    /// How far sideways the depth-only pick reaches from the tapped point.
    static let reachWithoutMask = 0.15
    /// How far sideways readings count when looking for the supporting surface.
    static let surfaceSearchRadius = 0.30
    static let heightStep = 0.005
    static let surfaceClearance = 0.004
    static let fewestPoints = 40

    public static func find(
        in frame: FusionFrame, tappedColumn: Double, tappedRow: Double, mask: SubjectMask?
    ) -> Result<SubjectBox, SubjectPickError> {
        let points = worldPoints(of: frame)
        guard let tapped = nearestPoint(to: tappedColumn, tappedRow, in: points) else {
            return .failure(.noDepthThere)
        }
        // An outline that covers none of the depth readings is no use; fall back to depth.
        var useMask = false
        if let mask {
            useMask = points.contains { mask.contains(across: $0.across, down: $0.down) }
        }
        var subject: [Vec3] = []
        var rest: [Vec3] = []
        for point in points {
            if isSubject(point, tapped: tapped.world, mask: useMask ? mask : nil) {
                subject.append(point.world)
            } else {
                rest.append(point.world)
            }
        }
        // With an outline, the surface is looked for among the readings outside it.
        // Without one, the rough "subject" includes the surface round the part, so every
        // reading is used; the surface still wins because it holds the most readings.
        let floor = surfaceHeight(below: tapped.world, among: useMask ? rest : points.map(\.world))
        if let floor, tapped.world.y <= floor + surfaceClearance, !useMask {
            return .failure(.tappedTheSurface)
        }
        if let floor {
            subject.removeAll { $0.y <= floor + surfaceClearance }
        }
        guard subject.count >= fewestPoints else {
            if let floor, tapped.world.y <= floor + surfaceClearance {
                return .failure(.tappedTheSurface)
            }
            return .failure(.notEnoughPoints)
        }
        let bounds = box(around: subject, floor: floor)
        return .success(SubjectBox(bounds: bounds, floorHeight: floor, usedMask: useMask, pointCount: subject.count))
    }

    /// One usable reading: where it is in the world and where it is in the picture
    /// (as fractions across and down, matching `SubjectMask`).
    struct PicturePoint {
        let column: Int
        let row: Int
        let across: Double
        let down: Double
        let world: Vec3
    }

    static func worldPoints(of frame: FusionFrame) -> [PicturePoint] {
        let depth = frame.depth
        var points: [PicturePoint] = []
        for row in 0..<depth.height {
            for column in 0..<depth.width {
                let metres = depth.depths[row * depth.width + column]
                guard DepthFrame.isValid(metres), depth.confidenceLevel(column: column, row: row) != .low else {
                    continue
                }
                let local = frame.cameraPoint(column: column, row: row, depth: Double(metres))
                points.append(
                    PicturePoint(
                        column: column, row: row, across: (Double(column) + 0.5) / Double(depth.width),
                        down: (Double(row) + 0.5) / Double(depth.height), world: frame.cameraToWorld.apply(to: local)))
            }
        }
        return points
    }

    /// The reading under the finger, or the nearest within 5 pixels.
    static func nearestPoint(to column: Double, _ row: Double, in points: [PicturePoint]) -> PicturePoint? {
        let reach = 5.0
        var best: PicturePoint?
        var bestDistance = Double.infinity
        for point in points {
            let across = Double(point.column) - column
            let down = Double(point.row) - row
            let distance = (across * across + down * down).squareRoot()
            if distance <= reach, distance < bestDistance {
                best = point
                bestDistance = distance
            }
        }
        return best
    }

    static func isSubject(_ point: PicturePoint, tapped: Vec3, mask: SubjectMask?) -> Bool {
        if let mask {
            return mask.contains(across: point.across, down: point.down)
        }
        return sidewaysDistance(point.world, tapped) <= reachWithoutMask && point.world.y < tapped.y + 0.30
    }

    /// The most common height among the readings near and below the tapped point, if
    /// enough of them agree to be a surface (SB-3).
    static func surfaceHeight(below tapped: Vec3, among rest: [Vec3]) -> Double? {
        let nearby = rest.filter {
            sidewaysDistance($0, tapped) <= surfaceSearchRadius && $0.y <= tapped.y + heightStep
        }
        guard nearby.count >= 30 else { return nil }
        var counts: [Int: Int] = [:]
        for point in nearby {
            counts[Int((point.y / heightStep).rounded(.down)), default: 0] += 1
        }
        // The busiest step; on a tie, the lower one.
        let busiest = counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }
        guard let busiest, busiest.value >= 30, Double(busiest.value) >= 0.15 * Double(nearby.count) else {
            return nil
        }
        let step = busiest.key
        // Average the heights in the winning step and its two neighbours.
        let band = nearby.filter { abs(Int(($0.y / heightStep).rounded(.down)) - step) <= 1 }
        return band.reduce(0) { $0 + $1.y } / Double(band.count)
    }

    /// The box around the subject's points (SB-4).
    static func box(around points: [Vec3], floor: Double?) -> Box {
        func spread(_ values: [Double]) -> (low: Double, high: Double) {
            let sorted = values.sorted()
            let low = sorted[Int(Double(sorted.count - 1) * 0.02)]
            let high = sorted[Int(Double(sorted.count - 1) * 0.98)]
            return (low, high)
        }
        let spanX = spread(points.map(\.x))
        let spanY = spread(points.map(\.y))
        let spanZ = spread(points.map(\.z))
        func margin(_ low: Double, _ high: Double) -> Double { max(0.01, (high - low) * 0.10) }
        var minimum = Vec3(spanX.low - margin(spanX.low, spanX.high), 0, spanZ.low - margin(spanZ.low, spanZ.high))
        var maximum = Vec3(spanX.high + margin(spanX.low, spanX.high), 0, spanZ.high + margin(spanZ.low, spanZ.high))
        minimum.y = floor.map { $0 + 0.002 } ?? spanY.low - margin(spanY.low, spanY.high)
        maximum.y = spanY.high + max(0.02, (spanY.high - spanY.low) * 0.20)
        return SubjectBox(bounds: Box(minimum: minimum, maximum: maximum), floorHeight: floor).scaled(by: 1).bounds
    }

    static func sidewaysDistance(_ first: Vec3, _ second: Vec3) -> Double {
        let across = first.x - second.x
        let along = first.z - second.z
        return (across * across + along * along).squareRoot()
    }
}
