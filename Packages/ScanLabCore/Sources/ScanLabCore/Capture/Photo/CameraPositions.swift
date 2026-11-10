import Foundation

/// A turn in space written as a unit quaternion: the vector part (x, y, z) and the
/// scalar part (usually called w). It is the form the platform reports camera
/// orientation in, and the form most photogrammetry tools read.
public struct Quaternion: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    /// The scalar part, written "qw" in the file.
    public var scalar: Double

    public init(x: Double, y: Double, z: Double, scalar: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.scalar = scalar
    }

    public static let identity = Quaternion(x: 0, y: 0, z: 0, scalar: 1)
}

/// The camera's lens numbers for one photograph, in pixels: the focal lengths across
/// and down, and the picture centre (the "pinhole" model; written fx, fy, cx, cy in
/// the file).
public struct CameraIntrinsics: Equatable, Sendable {
    public var focalX: Double
    public var focalY: Double
    public var centreX: Double
    public var centreY: Double

    public init(focalX: Double, focalY: Double, centreX: Double, centreY: Double) {
        self.focalX = focalX
        self.focalY = focalY
        self.centreX = centreX
        self.centreY = centreY
    }
}

/// Where the camera was, and which way it pointed, for one photograph, as worked out
/// by the platform while building the model.
public struct CameraPosition: Equatable, Sendable {
    /// The platform's number for the photograph.
    public var sample: Int
    /// The photograph's file name in `Images/`, when the platform says which it is.
    public var imageName: String?
    /// Position in metres, in the model's own coordinates (y up).
    public var position: Vec3
    public var rotation: Quaternion
    /// Lens numbers, when the platform reports them (iOS 26 and later).
    public var intrinsics: CameraIntrinsics?

    public init(
        sample: Int, imageName: String?, position: Vec3, rotation: Quaternion, intrinsics: CameraIntrinsics? = nil
    ) {
        self.sample = sample
        self.imageName = imageName
        self.position = position
        self.rotation = rotation
        self.intrinsics = intrinsics
    }
}

/// Writes `camera-positions.csv` for a raw capture (FR-7.5): one row per photograph,
/// readable by a spreadsheet or a script on the computer.
///
/// ```
/// sample,image,x_m,y_m,z_m,qx,qy,qz,qw,fx_px,fy_px,cx_px,cy_px
/// 0,IMG_0000.HEIC,0.120000,0.045000,-0.010000,0.000000,0.707107,0.000000,0.707107,1520.250,...
/// ```
public enum CameraPositionsFile {
    public static let header = "sample,image,x_m,y_m,z_m,qx,qy,qz,qw,fx_px,fy_px,cx_px,cy_px"

    /// The whole file, rows in photograph order. Missing values are left empty.
    public static func csv(_ positions: [CameraPosition]) -> String {
        var lines = [header]
        for position in positions.sorted(by: { $0.sample < $1.sample }) {
            lines.append(row(position))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func row(_ position: CameraPosition) -> String {
        let point = position.position
        let place = [point.x, point.y, point.z].map { number($0, 6) }
        let rotation = position.rotation
        let turn = [rotation.x, rotation.y, rotation.z, rotation.scalar].map { number($0, 6) }
        var lens = ["", "", "", ""]
        if let intrinsics = position.intrinsics {
            lens = [intrinsics.focalX, intrinsics.focalY, intrinsics.centreX, intrinsics.centreY].map { number($0, 3) }
        }
        let fields = [String(position.sample), field(position.imageName ?? "")] + place + turn + lens
        return fields.joined(separator: ",")
    }

    /// A number with a fixed count of decimals and "." as the decimal point whatever
    /// the phone's region. Not-a-number is written as an empty field.
    static func number(_ value: Double, _ decimals: Int) -> String {
        guard value.isFinite else { return "" }
        return String(format: "%.\(decimals)f", locale: nil, value)
    }

    /// A text field, quoted when it holds a comma, quote or line break (the usual CSV
    /// rule: quotes inside are doubled).
    static func field(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
