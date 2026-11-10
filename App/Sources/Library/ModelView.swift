import ScanLabCore
import SceneKit
import SwiftUI
import UIKit

/// The turnable, zoomable 3D model on Scan detail (FR-6.4): drag to turn, pinch to
/// zoom, two-finger drag to move. "Reset view" puts the camera back.
///
/// Why SceneKit's `SCNView` (decision recorded in the U05 functional design): its
/// built-in camera control gives turn, zoom and move with no gesture code of ours, it
/// lights a model by itself, and it draws a few hundred thousand faces without effort.
/// RealityKit is Apple's newer engine, but on iPhone its non-AR viewing and camera
/// controls need more setup and could not be tried here without a Mac. SceneKit is no
/// longer gaining features, so this view is kept small and self-contained, ready to be
/// swapped if that ever matters.
struct ModelView: UIViewRepresentable {
    let geometry: ViewerGeometry
    /// Changing this number puts the camera back to where it started.
    let resetCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        scene.rootNode.addChildNode(Self.modelNode(for: geometry))
        let camera = Self.cameraNode(radius: geometry.radius)
        scene.rootNode.addChildNode(camera)
        view.scene = scene
        view.pointOfView = camera
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.target = SCNVector3Zero
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .secondarySystemBackground
        context.coordinator.startTransform = camera.transform
        context.coordinator.resetCount = resetCount
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard context.coordinator.resetCount != resetCount else { return }
        context.coordinator.resetCount = resetCount
        view.pointOfView?.transform = context.coordinator.startTransform
    }

    /// Remembers where the camera started.
    @MainActor
    final class Coordinator {
        var startTransform = SCNMatrix4Identity
        var resetCount = 0
    }

    /// The model as one SceneKit node. Our models have z pointing up; SceneKit has y
    /// pointing up, so the node is turned a quarter-turn about x to stand it upright.
    private static func modelNode(for geometry: ViewerGeometry) -> SCNNode {
        let positions = geometry.positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let normals = geometry.normals.withUnsafeBufferPointer { Data(buffer: $0) }
        let count = geometry.cornerCount
        // Corners are listed face by face, so the faces are simply 0, 1, 2, then 3, 4, 5…
        let indices = (0..<UInt32(count)).map { $0 }.withUnsafeBufferPointer { Data(buffer: $0) }
        let stride = 3 * MemoryLayout<Float>.size
        let vertexSource = SCNGeometrySource(
            data: positions, semantic: .vertex, vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: stride)
        let normalSource = SCNGeometrySource(
            data: normals, semantic: .normal, vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: stride)
        let element = SCNGeometryElement(
            data: indices, primitiveType: .triangles, primitiveCount: count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size)
        let shape = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        material.lightingModel = .blinn
        // Scanned faces do not always face outwards; show both sides.
        material.isDoubleSided = true
        shape.materials = [material]
        let node = SCNNode(geometry: shape)
        node.eulerAngles.x = -Float.pi / 2
        return node
    }

    /// A camera in front, to the right and above, far enough back to see the whole
    /// model: the same three-quarter view as the thumbnail.
    private static func cameraNode(radius: Double) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.automaticallyAdjustsZRange = true
        let node = SCNNode()
        node.camera = camera
        // The distance at which a ball of this radius just fits the 40° view, plus a
        // margin. A model with no size gets a nominal 10 cm.
        let fit = max(radius, 0.05) / sin(20 * Double.pi / 180) * 1.15
        let direction = simd_normalize(SIMD3<Float>(1, 1, 1.4))
        node.simdPosition = direction * Float(fit)
        node.simdLook(at: .zero)
        return node
    }
}
