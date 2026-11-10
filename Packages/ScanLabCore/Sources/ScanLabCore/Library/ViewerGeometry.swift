import Foundation

/// A model prepared for the 3D view on Scan detail: flat lists of numbers in the form
/// the phone's graphics hardware takes directly.
///
/// Every face gets its own three corners, each carrying the face's direction (its
/// "normal"). Sharing corners between faces would blur the shading across edges;
/// giving each face its own corners shows the facets exactly as stored, which is the
/// honest picture of a scan. It costs three times the corners: about 14 MB for a
/// 200,000-face scan, comfortably within the phone's means.
///
/// The model is moved so its centre is at the origin, which is the point the view
/// turns around.
public struct ViewerGeometry: Equatable, Sendable {
    /// x, y, z for each corner, three corners per face, in metres.
    public let positions: [Float]
    /// The face's direction for each corner, length 1 (zero for a face with no area).
    public let normals: [Float]
    /// Half the length of the model's diagonal, in metres: the size of a ball holding
    /// the whole model. Used to place the camera. Zero for an empty model.
    public let radius: Double

    /// How many corners there are (three per face).
    public var cornerCount: Int { positions.count / 3 }

    public init(_ mesh: Mesh) {
        let centre = mesh.boundingBox?.centre ?? .zero
        var positions: [Float] = []
        var normals: [Float] = []
        positions.reserveCapacity(mesh.faceCount * 9)
        normals.reserveCapacity(mesh.faceCount * 9)
        for (index, triangle) in mesh.triangles.enumerated() {
            let normal = mesh.faceNormal(index)
            for corner in triangle.indices {
                let point = mesh.vertices[corner] - centre
                positions += [Float(point.x), Float(point.y), Float(point.z)]
                normals += [Float(normal.x), Float(normal.y), Float(normal.z)]
            }
        }
        self.positions = positions
        self.normals = normals
        radius = (mesh.boundingBox?.diagonal ?? 0) / 2
    }
}
