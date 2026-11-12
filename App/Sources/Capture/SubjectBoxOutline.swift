import Foundation
import RealityKit
import ScanLabCore
import UIKit

/// Draws the subject box over the camera picture as 12 thin bars, one per edge (SB-6):
/// yellow while proposed, green once locked.
///
/// RealityKit has no ready-made wireframe box, so each edge is a long, thin box 2 mm
/// thick. The bars are placed relative to an anchor at the box's centre, in the
/// platform's world (metres, y up), so the box stays put as the phone moves.
@MainActor
enum SubjectBoxOutline {
    static let thickness: Float = 0.002

    static func make(for box: SubjectBox, locked: Bool) -> AnchorEntity {
        let bounds = box.bounds
        let centre = bounds.centre
        let size = bounds.size
        let anchor = AnchorEntity(world: SIMD3<Float>(Float(centre.x), Float(centre.y), Float(centre.z)))
        let material = UnlitMaterial(color: locked ? .systemGreen : .systemYellow)
        let half = SIMD3<Float>(Float(size.x), Float(size.y), Float(size.z)) / 2
        // For each axis, four bars run along it, at the four corners of the other two.
        for axis in 0..<3 {
            var extent = SIMD3<Float>(repeating: thickness)
            extent[axis] = half[axis] * 2
            let mesh = MeshResource.generateBox(width: extent.x, height: extent.y, depth: extent.z)
            let others = [(axis + 1) % 3, (axis + 2) % 3]
            for corner in 0..<4 {
                var position = SIMD3<Float>(repeating: 0)
                position[others[0]] = corner & 1 == 0 ? -half[others[0]] : half[others[0]]
                position[others[1]] = corner & 2 == 0 ? -half[others[1]] : half[others[1]]
                let bar = ModelEntity(mesh: mesh, materials: [material])
                bar.position = position
                anchor.addChild(bar)
            }
        }
        return anchor
    }
}
