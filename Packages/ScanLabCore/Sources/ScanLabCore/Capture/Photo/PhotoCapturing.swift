import Foundation

/// The detail levels Apple's photogrammetry knows about (FR-4.2). On iPhone only
/// `reduced` is available (Apple's `PhotogrammetrySession.Request.Detail`
/// documentation, checked 2026-11-11); the others need a Mac. They are listed so the
/// level stored with a scan can always be named, whatever a later system offers.
public enum PhotoDetailLevel: String, CaseIterable, Sendable {
    case preview
    case reduced
    case medium
    case full
    case raw

    /// The word stored in the scan's manifest and shown on Scan detail, for example
    /// "reduced" (shown as "Photos · reduced detail").
    public var manifestValue: String { rawValue }
}

/// The stage of model building, as the platform reports it. Used only for the text on
/// screen and in the log.
public enum BuildStage: String, CaseIterable, Sendable {
    case preparing
    case aligningPhotos
    case makingPoints
    case makingMesh
    case colouring
    case tidying

    /// Plain words for the screen, for example "making the mesh".
    public var displayName: String {
        switch self {
        case .preparing: "preparing the photos"
        case .aligningPhotos: "lining up the photos"
        case .makingPoints: "finding points in 3D"
        case .makingMesh: "making the mesh"
        case .colouring: "colouring the surface"
        case .tidying: "tidying up"
        }
    }
}

/// One progress report from a model build.
public struct BuildUpdate: Equatable, Sendable {
    /// From 0 (just started) to 1 (finished).
    public var fraction: Double
    public var stage: BuildStage?
    /// The platform's own estimate of the time left, when it gives one.
    public var secondsRemaining: Double?

    public init(fraction: Double, stage: BuildStage? = nil, secondsRemaining: Double? = nil) {
        self.fraction = fraction
        self.stage = stage
        self.secondsRemaining = secondsRemaining
    }
}

/// What a finished build produced.
public struct PhotoBuildResult: Equatable, Sendable {
    /// The OBJ file the model was written to, in metres with y pointing up.
    public var modelFile: URL
    /// How many photographs have a camera position in `camera-positions.csv`.
    public var cameraPositions: Int
    /// How the model file was made, for the log: "obj" when the platform wrote OBJ
    /// directly, or "usdz-modelio" when it was converted on the phone.
    public var route: String

    public init(modelFile: URL, cameraPositions: Int, route: String) {
        self.modelFile = modelFile
        self.cameraPositions = cameraPositions
        self.route = route
    }
}

/// Something that happened while a model was being built.
public enum PhotoBuildEvent: Equatable, Sendable {
    /// All photographs were read and building has begun.
    case photosRead
    /// A photograph could not be used. Building carries on without it.
    case photoSkipped(reason: String)
    /// Progress. Arrives every few seconds while building.
    case progress(BuildUpdate)
    /// The model is finished and written to a file.
    case built(PhotoBuildResult)
}

/// The port for photo capture (component-methods.md, `PhotoCapturing`; ADR-006). The
/// app supplies `ObjectCapturePhotoCapture`, which uses Apple's Object Capture.
///
/// Taking the photographs is done by the platform's own guided capture screen, which
/// cannot be separated from its session; so this port covers what happens around it:
/// whether the phone can do it at all, and building a model from photographs already
/// on disk. Because building reads only the folder, it can be started again from the
/// same photographs after a failure or an interruption, without capturing again
/// (FR-4.3).
public protocol PhotoCapturing: Sendable {
    /// The detail level `build` uses: always `.reduced` on an iPhone.
    var detailLevel: PhotoDetailLevel { get }

    /// Checks the phone can capture: it has the depth sensor Object Capture needs and
    /// the camera may be used (asking the owner the first time). Throws
    /// `PhotoCaptureError.unsupportedDevice` or `.cameraDenied` when not.
    func prepare() async throws

    /// Builds a model from the photographs in `capture.images`. Events arrive in order;
    /// the stream ends after `.built`, or throws a `PhotoCaptureError`. Stopping the
    /// task that reads the stream cancels the build.
    func build(_ capture: RawCaptureFolders) -> AsyncThrowingStream<PhotoBuildEvent, any Error>
}

/// The folders of one photo capture, all inside one capture folder:
///
/// ```
/// <capture>/                 named by a fresh identity
///     Images/                the photographs (HEIC, with depth and gravity inside)
///     Checkpoint/            the platform's working data, so a build can resume
///     Model/                 the built model (OBJ, material and textures)
///     camera-positions.csv   where the camera was for each photograph
///     README.txt             what the folder holds, for whoever opens an export
/// ```
///
/// When the owner keeps the raw capture, only the photographs, the camera positions
/// and the README are kept (see `RawCaptureFiles.prepareForKeeping`).
public struct RawCaptureFolders: Equatable, Sendable, Identifiable {
    public static let imagesName = "Images"
    public static let checkpointName = "Checkpoint"
    public static let modelName = "Model"
    public static let cameraPositionsName = "camera-positions.csv"
    public static let readMeName = "README.txt"

    /// What stays in a kept raw capture.
    public static let keptNames: Set<String> = [imagesName, cameraPositionsName, readMeName]

    /// The capture folder itself.
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// A new capture folder inside `parent`, named by `id`. Nothing is created on
    /// disk: Object Capture insists on creating its own empty folders.
    public static func new(in parent: URL, id: UUID = UUID()) -> RawCaptureFolders {
        RawCaptureFolders(root: parent.appending(path: id.uuidString, directoryHint: .isDirectory))
    }

    public var id: String { root.lastPathComponent }
    public var images: URL { root.appending(path: Self.imagesName, directoryHint: .isDirectory) }
    public var checkpoint: URL { root.appending(path: Self.checkpointName, directoryHint: .isDirectory) }
    public var model: URL { root.appending(path: Self.modelName, directoryHint: .isDirectory) }
    public var cameraPositions: URL { root.appending(path: Self.cameraPositionsName) }
    public var readMe: URL { root.appending(path: Self.readMeName) }
}
