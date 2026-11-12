import Foundation

/// What the screen needs to draw the coverage dome and say where to go next (CD-3, CD-4).
public struct CoverageSummary: Equatable, Sendable {
    /// One entry per direction: ring × 8 + step round. Ring 0 is the side, ring 2 above.
    public var covered: [Bool]
    /// The direction the camera is in now, if it is looking at the box.
    public var current: Int?
    public var prompt: String?

    public init(covered: [Bool], current: Int?, prompt: String?) {
        self.covered = covered
        self.current = current
        self.prompt = prompt
    }

    public var coveredCount: Int { covered.filter { $0 }.count }

    public var fraction: Double {
        covered.isEmpty ? 0 : Double(coveredCount) / Double(covered.count)
    }

    public var isComplete: Bool { !covered.isEmpty && coveredCount == covered.count }

    /// "15 of 24 sides seen", for the screen reader.
    public var spoken: String {
        "\(coveredCount) of \(covered.count) directions covered"
    }
}

/// Keeps count of which directions round the subject have been seen (CD-1, CD-2).
///
/// Picture a dome over the box, cut like an orange into 8 segments going round, and
/// into three bands going up: the side (0–25° above the box's centre), raised (25–55°)
/// and above (55–90°). That gives 24 patches. Each time a depth picture is fused, the
/// camera's position says which patch it was looking from; after 3 pictures a patch is
/// covered.
public struct CoverageDome: Equatable, Sendable {
    public static let stepsRound = 8
    public static let rings = 3
    public static let picturesToCover = 3
    /// Upper edge of each band, in degrees above the box's centre.
    static let ringTops = [25.0, 55.0, 90.1]
    static let lowestAngle = -10.0
    static let farthest = 1.0

    public let centre: Vec3
    public private(set) var counts = [Int](repeating: 0, count: stepsRound * rings)

    public init(centre: Vec3) {
        self.centre = centre
    }

    /// The patch a camera position looks from, or nil when it is below the box, too far
    /// away, or at the centre itself.
    public func direction(of camera: Vec3) -> Int? {
        let offset = camera - centre
        let sideways = (offset.x * offset.x + offset.z * offset.z).squareRoot()
        let distance = offset.length
        guard distance > 0, distance <= Self.farthest else { return nil }
        let elevation = atan2(offset.y, sideways) * 180 / .pi
        guard elevation >= Self.lowestAngle, let ring = Self.ringTops.firstIndex(where: { elevation < $0 }) else {
            return nil
        }
        // The angle round, measured from +x towards +z, as 0 to 360°.
        var azimuth = atan2(offset.z, offset.x) * 180 / .pi
        if azimuth < 0 {
            azimuth += 360
        }
        let step = Int(azimuth / (360 / Double(Self.stepsRound))) % Self.stepsRound
        return ring * Self.stepsRound + step
    }

    /// Counts one fused picture, if the box's centre was in it (CD-2). Returns the patch
    /// it counted for.
    @discardableResult
    public mutating func record(_ frame: FusionFrame) -> Int? {
        guard sees(frame), let patch = direction(of: frame.cameraPosition) else { return nil }
        counts[patch] += 1
        return patch
    }

    /// True when the box's centre lands inside the picture, in front of the camera.
    func sees(_ frame: FusionFrame) -> Bool {
        let local = frame.worldToCamera(centre)
        let depth = -local.z
        guard depth > 0 else { return false }
        let column = frame.intrinsics.focalX * local.x / depth + frame.intrinsics.centreX
        let row = -frame.intrinsics.focalY * local.y / depth + frame.intrinsics.centreY
        return column >= 0 && column < Double(frame.depth.width) && row >= 0 && row < Double(frame.depth.height)
    }

    public func summary(cameraAt camera: Vec3?) -> CoverageSummary {
        let covered = counts.map { $0 >= Self.picturesToCover }
        let current = camera.flatMap { direction(of: $0) }
        return CoverageSummary(covered: covered, current: current, prompt: prompt(covered: covered, current: current))
    }

    /// Points to the nearest uncovered patch (CD-4): height first, then round.
    ///
    /// Going round: the angle is measured from +x towards +z. With y up, a person facing
    /// the subject who steps to their left moves towards larger angles (the tests walk
    /// through an example). So a target at a larger angle, by the shorter way round,
    /// means "go round to your left".
    func prompt(covered: [Bool], current: Int?) -> String? {
        if !covered.contains(false) {
            return "All round covered. Tap Finish when ready."
        }
        guard let current else { return "Point the phone at the box." }
        let ring = current / Self.stepsRound
        let step = current % Self.stepsRound
        var best: (patch: Int, cost: Int)?
        for patch in covered.indices where !covered[patch] {
            let cost = abs(patch / Self.stepsRound - ring) * 2 + Self.stepsBetween(step, patch % Self.stepsRound)
            if best == nil || cost < (best?.cost ?? .max) {
                best = (patch, cost)
            }
        }
        guard let target = best?.patch else { return nil }
        let targetRing = target / Self.stepsRound
        if targetRing > ring {
            return "Raise the phone and look down on it."
        }
        if targetRing < ring {
            return "Lower the phone to look at its side."
        }
        if target == current {
            return "Hold here a moment."
        }
        return Self.signedSteps(from: step, to: target % Self.stepsRound) > 0
            ? "Go round to your left." : "Go round to your right."
    }

    /// Steps between two positions round, the shorter way (0 to 4).
    static func stepsBetween(_ first: Int, _ second: Int) -> Int {
        abs(signedSteps(from: first, to: second))
    }

    /// Steps from one position round to another, the shorter way: positive towards
    /// larger angles, negative towards smaller ones.
    static func signedSteps(from first: Int, to second: Int) -> Int {
        var difference = (second - first) % stepsRound
        if difference > stepsRound / 2 {
            difference -= stepsRound
        } else if difference < -stepsRound / 2 {
            difference += stepsRound
        }
        return difference
    }
}
