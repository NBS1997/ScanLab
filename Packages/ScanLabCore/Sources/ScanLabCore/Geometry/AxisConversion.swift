import Foundation

// Apple's AR and Object Capture worlds point the y axis up. ScanLab's library, thumbnails
// and exports treat z as up, which is what Fusion and most CAD tools expect. Both capture
// methods call this once, just before a mesh is saved, so everything stored is z-up.

extension Vec3 {
    /// The same point described with z pointing up instead of y.
    ///
    /// In a y-up world, "up" is +y and "towards the viewer" is +z. Turning that world a
    /// quarter-turn about the x axis makes old +y the new +z and old +z the new -y, so
    /// (x, y, z) becomes (x, -z, y). Lengths and handedness are unchanged.
    public var yUpToZUp: Vec3 { Vec3(x, -z, y) }
}

extension Mesh {
    /// The same mesh with z pointing up instead of y. A pure rotation, so the triangles
    /// keep their corner order and their outsides still face outwards.
    public func convertedFromYUp() -> Mesh {
        Mesh(unchecked: vertices.map(\.yUpToZUp), triangles: triangles)
    }
}
