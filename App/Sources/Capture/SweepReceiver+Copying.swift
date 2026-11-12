import ARKit
import Foundation
import ScanLabCore

/// Copies ARKit's values into Core's plain types for the sweep (ADR-003): mesh anchors
/// into `MeshPart`s, and depth frames into `FusionFrame`s (U14). Kept apart from
/// `SweepReceiver` so that file stays readable.
extension SweepReceiver {
    // MARK: - Copying ARKit's mesh buffers

    /// Copies one anchor's surface into a Core `MeshPart`.
    ///
    /// The corners and triangles live in graphics-memory buffers ("Metal buffers"). The
    /// buffer is read through a raw pointer: each corner is three 32-bit floats at
    /// `offset + stride × number`; each triangle is three corner numbers, each
    /// `bytesPerIndex` bytes long. Positions are relative to the anchor; its
    /// `transform` (a 4 × 4 matrix, stored column by column) moves them into the world.
    static func part(from anchor: ARMeshAnchor) -> MeshPart? {
        let geometry = anchor.geometry
        let source = geometry.vertices
        let faces = geometry.faces
        guard source.format == .float3, faces.indexCountPerPrimitive == 3,
            faces.bytesPerIndex == 4 || faces.bytesPerIndex == 2
        else { return nil }

        let vertexBytes = source.buffer.contents()
        var vertices: [Vec3] = []
        vertices.reserveCapacity(source.count)
        for number in 0..<source.count {
            let start = source.offset + source.stride * number
            let x = vertexBytes.loadUnaligned(fromByteOffset: start, as: Float.self)
            let y = vertexBytes.loadUnaligned(fromByteOffset: start + 4, as: Float.self)
            let z = vertexBytes.loadUnaligned(fromByteOffset: start + 8, as: Float.self)
            vertices.append(Vec3(Double(x), Double(y), Double(z)))
        }

        let indexBytes = faces.buffer.contents()
        let width = faces.bytesPerIndex
        func corner(_ position: Int) -> Int {
            let offset = position * width
            if width == 2 {
                return Int(indexBytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
            }
            return Int(indexBytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
        var triangles: [Triangle] = []
        triangles.reserveCapacity(faces.count)
        for face in 0..<faces.count {
            triangles.append(Triangle(corner(face * 3), corner(face * 3 + 1), corner(face * 3 + 2)))
        }

        let matrix = anchor.transform
        let columns = [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
        let values = columns.flatMap { [Double($0.x), Double($0.y), Double($0.z), Double($0.w)] }
        guard let transform = Transform(columnMajor: values) else { return nil }
        return MeshPart(vertices: vertices, triangles: triangles, transform: transform)
    }

    // MARK: - Copying depth pictures (U14)

    /// Copies a frame's depth picture, lens numbers and camera position into Core's
    /// `FusionFrame`.
    ///
    /// The lens numbers ("intrinsics", a 3 × 3 matrix stored column by column) are for
    /// the colour picture, which is 1920 pixels wide; the depth picture is 256 wide and
    /// lines up with it, so the numbers are scaled down by the ratio of the widths. The
    /// camera's position is a 4 × 4 matrix in the same column order as mesh anchors.
    static func fusionFrame(from frame: ARFrame) -> FusionFrame? {
        guard let data = frame.sceneDepth,
            let depth = FrameReceiver.depthFrame(from: data, timestamp: frame.timestamp)
        else { return nil }
        let camera = frame.camera
        let imageWidth = Double(camera.imageResolution.width)
        guard imageWidth > 0 else { return nil }
        let lens = camera.intrinsics
        let intrinsics = CameraIntrinsics(
            focalX: Double(lens.columns.0.x), focalY: Double(lens.columns.1.y),
            centreX: Double(lens.columns.2.x), centreY: Double(lens.columns.2.y)
        ).scaled(by: Double(depth.width) / imageWidth)
        let pose = camera.transform
        let columns = [pose.columns.0, pose.columns.1, pose.columns.2, pose.columns.3]
        let values = columns.flatMap { [Double($0.x), Double($0.y), Double($0.z), Double($0.w)] }
        guard let cameraToWorld = Transform(columnMajor: values) else { return nil }
        return FusionFrame(depth: depth, intrinsics: intrinsics, cameraToWorld: cameraToWorld)
    }
}
