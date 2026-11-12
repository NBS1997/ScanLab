import Foundation

/// Draws the surface held in a fusion grid (DF-3), using the "surface nets" method.
///
/// Think of the cube centres as the corners of a second grid of "cells". The surface
/// passes through a cell when some of its eight corners are outside (positive distance)
/// and some inside (zero or negative).
///
/// 1. **Corners of the mesh.** Every such cell gets one mesh corner: on each of the
///    cell's 12 edges whose ends disagree, the crossing point is found by straight-line
///    interpolation, and the mesh corner is the average of those crossings.
/// 2. **Faces.** Wherever two neighbouring cubes disagree, the surface crosses the line
///    between them. The four cells that share that line all have corners, and joining
///    them makes a four-sided face, stored as two triangles. The face is wound so its
///    outside points from the inside cube towards the outside one.
///
/// A cell is only used when all eight of its corners have been seen enough, so poorly
/// seen areas leave holes rather than guesses.
enum SurfaceNets {
    static func mesh(from volume: inout VoxelVolume, minimumWeight: Float) -> Mesh {
        var seen: [(index: VoxelIndex, distance: Float)] = []
        volume.forEachSeen(minimumWeight: minimumWeight) { seen.append(($0, $1)) }

        var cornerOfCell: [VoxelIndex: Int] = [:]
        var vertices: [Vec3] = []
        for cube in seen {
            if let point = crossingPoint(in: cube.index, volume: &volume, minimumWeight: minimumWeight) {
                cornerOfCell[cube.index] = vertices.count
                vertices.append(point)
            }
        }

        var triangles: [Triangle] = []
        for cube in seen {
            for axis in 0..<3 {
                let neighbour = cube.index + VoxelIndex.unit(axis)
                guard let other = volume.distance(at: neighbour, minimumWeight: minimumWeight),
                    (cube.distance > 0) != (other > 0),
                    let quad = quad(around: cube.index, axis: axis, cornerOfCell: cornerOfCell)
                else { continue }
                // `quad` faces along +axis. Flip it when the outside is the other way.
                let corners = other > 0 ? quad : [quad[0], quad[3], quad[2], quad[1]]
                triangles.append(Triangle(corners[0], corners[1], corners[2]))
                triangles.append(Triangle(corners[0], corners[2], corners[3]))
            }
        }
        return Mesh(unchecked: vertices, triangles: triangles)
    }

    /// The mesh corners of the four cells around the line from `index` to the next cube
    /// along `axis`, ordered so the face's outside points along +axis; nil if any of the
    /// four cells has no corner.
    ///
    /// With the other two axes taken in turn (x → y, z; y → z, x; z → x, y), the four
    /// cells sit in the quarters (+,+), (−,+), (−,−), (+,−) around the line. That order
    /// runs anticlockwise when seen from the +axis side, and anticlockwise means facing
    /// the viewer (see `Triangle`).
    static func quad(around index: VoxelIndex, axis: Int, cornerOfCell: [VoxelIndex: Int]) -> [Int]? {
        let first = VoxelIndex.unit((axis + 1) % 3)
        let second = VoxelIndex.unit((axis + 2) % 3)
        let cells = [index, index - first, index - first - second, index - second]
        let corners = cells.compactMap { cornerOfCell[$0] }
        return corners.count == 4 ? corners : nil
    }

    /// The mesh corner for the cell whose lowest corner is cube `index`, or nil when the
    /// surface does not pass through it or a corner has not been seen enough.
    static func crossingPoint(in index: VoxelIndex, volume: inout VoxelVolume, minimumWeight: Float) -> Vec3? {
        // Corner k of the cell is `index` plus (k & 1, k >> 1 & 1, k >> 2 & 1).
        var values = [Float](repeating: 0, count: 8)
        for corner in 0..<8 {
            let offset = VoxelIndex(Int32(corner & 1), Int32(corner >> 1 & 1), Int32(corner >> 2 & 1))
            guard let value = volume.distance(at: index + offset, minimumWeight: minimumWeight) else { return nil }
            values[corner] = value
        }
        var total = Vec3.zero
        var crossings = 0
        for corner in 0..<8 {
            for bit in [1, 2, 4] where corner & bit == 0 {
                let start = values[corner]
                let end = values[corner | bit]
                guard (start > 0) != (end > 0) else { continue }
                // Where the straight line from `start` to `end` passes zero (0 to 1).
                let fraction = Double(start / (start - end))
                total = total + position(of: corner) + (position(of: corner | bit) - position(of: corner)) * fraction
                crossings += 1
            }
        }
        guard crossings > 0 else { return nil }
        return volume.centre(of: index) + total / Double(crossings) * volume.voxelSize
    }

    /// Corner k's offset from the cell's lowest corner, in cubes.
    private static func position(of corner: Int) -> Vec3 {
        Vec3(Double(corner & 1), Double(corner >> 1 & 1), Double(corner >> 2 & 1))
    }
}
