import Foundation

/// Fusion's additions to the lens numbers shared with photo capture (`CameraPositions`).
extension CameraIntrinsics {
    /// The same camera for a picture `factor` times as wide. The platform gives the
    /// numbers for the colour picture (1920 pixels wide); the depth picture is 256 wide,
    /// so the depth sweep uses `scaled(by: 256 / 1920)`.
    public func scaled(by factor: Double) -> CameraIntrinsics {
        CameraIntrinsics(
            focalX: focalX * factor, focalY: focalY * factor, centreX: centreX * factor, centreY: centreY * factor)
    }

    public var isUsable: Bool {
        focalX.isFinite && focalY.isFinite && centreX.isFinite && centreY.isFinite && focalX > 0 && focalY > 0
    }
}

/// One depth picture ready to fuse: the readings, the camera's intrinsics at the depth
/// picture's size, and where the camera was.
///
/// Camera axes follow the platform: x to the right of the picture, y up, and the camera
/// looking along −z. `cameraToWorld` moves a point from those axes into the world.
public struct FusionFrame: Sendable {
    public let depth: DepthFrame
    public let intrinsics: CameraIntrinsics
    public let cameraToWorld: Transform

    public init(depth: DepthFrame, intrinsics: CameraIntrinsics, cameraToWorld: Transform) {
        self.depth = depth
        self.intrinsics = intrinsics
        self.cameraToWorld = cameraToWorld
    }

    /// The point a reading measured, in camera axes.
    ///
    /// A reading is the distance along the camera's viewing direction (not along the
    /// pixel's own ray), so the pixel's sideways offset from the centre, divided by the
    /// focal length, scales with it. Picture rows run downwards while camera y runs
    /// up, hence the minus sign on y; the camera looks along −z, hence −depth.
    public func cameraPoint(column: Int, row: Int, depth metres: Double) -> Vec3 {
        Vec3(
            (Double(column) - intrinsics.centreX) / intrinsics.focalX * metres,
            -(Double(row) - intrinsics.centreY) / intrinsics.focalY * metres,
            -metres)
    }

    /// Where the camera was, in the world.
    public var cameraPosition: Vec3 { cameraToWorld.translation }

    /// The reverse of `cameraToWorld`: a world point in camera axes.
    ///
    /// The camera's transform only turns and moves (it never stretches), and undoing a
    /// pure turn is the same as turning by its mirror image across the diagonal (the
    /// "transpose"): row and column swap places. So: subtract the camera's position,
    /// then multiply by the turn's columns instead of its rows.
    public func worldToCamera(_ point: Vec3) -> Vec3 {
        let offset = point - cameraToWorld.translation
        let turn = cameraToWorld
        return Vec3(
            turn.xRow.x * offset.x + turn.yRow.x * offset.y + turn.zRow.x * offset.z,
            turn.xRow.y * offset.x + turn.yRow.y * offset.y + turn.zRow.y * offset.z,
            turn.xRow.z * offset.x + turn.yRow.z * offset.y + turn.zRow.z * offset.z)
    }
}
