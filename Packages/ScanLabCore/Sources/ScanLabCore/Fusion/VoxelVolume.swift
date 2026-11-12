import Foundation

/// The whole-number position of one cube in the fusion grid: cube (x, y, z) is centred
/// on (x, y, z) × the voxel size, in metres.
struct VoxelIndex: Hashable, Sendable {
    var x: Int32
    var y: Int32
    var z: Int32

    init(_ x: Int32, _ y: Int32, _ z: Int32) {
        self.x = x
        self.y = y
        self.z = z
    }

    static func + (lhs: VoxelIndex, rhs: VoxelIndex) -> VoxelIndex {
        VoxelIndex(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: VoxelIndex, rhs: VoxelIndex) -> VoxelIndex {
        VoxelIndex(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    /// One step along axis 0 (x), 1 (y) or 2 (z).
    static func unit(_ axis: Int) -> VoxelIndex {
        switch axis {
        case 0: VoxelIndex(1, 0, 0)
        case 1: VoxelIndex(0, 1, 0)
        default: VoxelIndex(0, 0, 1)
        }
    }
}

/// The sparse fusion grid (DF-1, DF-6).
///
/// Storing every cube of a 1 m room at 4 mm would take 15 million cubes, nearly all of
/// them empty air. Instead the grid is cut into blocks of 8 × 8 × 8 cubes, and a block
/// only exists once a reading touches it. A dictionary maps a block's position to its
/// slot; each slot owns 512 entries in two flat arrays (distance and weight), which is
/// much faster than one dictionary entry per cube.
///
/// A weight of zero means "never seen". Each cube also remembers the number of the last
/// picture that changed it, so one picture changes a cube at most once (DF-1): the
/// lines of sight of neighbouring pixels pass through the same cube, and without this a
/// single picture would count as several views.
struct VoxelVolume {
    static let blockSide: Int32 = 8
    static let cubesPerBlock = 512

    let voxelSize: Double
    let maximumBlocks: Int
    private(set) var slots: [VoxelIndex: Int] = [:]
    private(set) var distances: [Float] = []
    private(set) var weights: [Float] = []
    private(set) var stamps: [UInt16] = []
    private(set) var isFull = false
    /// The current picture's number. Zero is never used, because new cubes start at zero.
    private var stamp: UInt16 = 1

    /// The last block looked up. Neighbouring cubes are usually in the same block, so
    /// this skips most dictionary lookups.
    private var cachedBlock = VoxelIndex(.max, .max, .max)
    private var cachedSlot: Int?

    init(voxelSize: Double, maximumBlocks: Int) {
        self.voxelSize = voxelSize
        self.maximumBlocks = max(maximumBlocks, 0)
    }

    var blockCount: Int { slots.count }

    /// The cube whose centre is nearest a point.
    func index(of point: Vec3) -> VoxelIndex {
        VoxelIndex(
            Int32(clamping: Int((point.x / voxelSize).rounded())),
            Int32(clamping: Int((point.y / voxelSize).rounded())),
            Int32(clamping: Int((point.z / voxelSize).rounded())))
    }

    func centre(of index: VoxelIndex) -> Vec3 {
        Vec3(Double(index.x), Double(index.y), Double(index.z)) * voxelSize
    }

    /// The stored distance of a cube seen with at least `minimumWeight`, or nil.
    mutating func distance(at index: VoxelIndex, minimumWeight: Float) -> Float? {
        guard let entry = entry(for: index, creating: false), weights[entry] >= minimumWeight,
            weights[entry] > 0
        else { return nil }
        return distances[entry]
    }

    /// Starts a new picture: from now on each cube may change once more.
    mutating func beginPicture() {
        // `&+` wraps from 65,535 back to 0 instead of crashing; 0 is then skipped.
        stamp &+= 1
        if stamp == 0 {
            stamp = 1
        }
    }

    /// Folds one reading into a cube's weighted average, unless this picture has already
    /// changed the cube. Does nothing once memory is full and the cube's block does not
    /// exist yet (DF-6).
    mutating func add(distance: Float, weight: Float, to index: VoxelIndex, maximumWeight: Float) {
        guard weight > 0, let entry = entry(for: index, creating: true), stamps[entry] != stamp else { return }
        stamps[entry] = stamp
        let old = weights[entry]
        distances[entry] = (distances[entry] * old + distance * weight) / (old + weight)
        weights[entry] = min(old + weight, maximumWeight)
    }

    /// Calls `body` with every cube seen with at least `minimumWeight`.
    func forEachSeen(minimumWeight: Float, _ body: (VoxelIndex, Float) -> Void) {
        let side = Self.blockSide
        for (block, slot) in slots {
            let base = slot * Self.cubesPerBlock
            for local in 0..<Self.cubesPerBlock {
                let weight = weights[base + local]
                guard weight > 0, weight >= minimumWeight else { continue }
                let offset = Int32(local)
                let index = VoxelIndex(
                    block.x * side + offset % side, block.y * side + (offset / side) % side,
                    block.z * side + offset / (side * side))
                body(index, distances[base + local])
            }
        }
    }

    /// Where a cube lives in the flat arrays. Shifting right by 3 divides by 8 rounding
    /// down, also for negative positions; `& 7` is the matching remainder (0 to 7).
    private mutating func entry(for index: VoxelIndex, creating: Bool) -> Int? {
        let block = VoxelIndex(index.x >> 3, index.y >> 3, index.z >> 3)
        let slot: Int
        if block == cachedBlock, let cachedSlot {
            slot = cachedSlot
        } else if let found = slots[block] {
            slot = found
        } else {
            guard creating else { return nil }
            guard slots.count < maximumBlocks else {
                isFull = true
                return nil
            }
            slot = slots.count
            slots[block] = slot
            distances.append(contentsOf: repeatElement(0, count: Self.cubesPerBlock))
            weights.append(contentsOf: repeatElement(0, count: Self.cubesPerBlock))
            stamps.append(contentsOf: repeatElement(0, count: Self.cubesPerBlock))
        }
        cachedBlock = block
        cachedSlot = slot
        let local = Int(index.x & 7) + Int(index.y & 7) * 8 + Int(index.z & 7) * 64
        return slot * Self.cubesPerBlock + local
    }
}
