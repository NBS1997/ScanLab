import ARKit
import AVFoundation
import Foundation
import Metal
import RealityKit
import ScanLabCore
import UIKit

/// The real sweep capture (U07, ADR-005): an ARKit world-tracking session with scene
/// reconstruction, behind Core's `SweepCapturing` port.
///
/// How the pieces fit:
/// - **The camera view** is RealityKit's `ARView` with its "show scene understanding"
///   option, which draws the reconstructed surface as a coloured wireframe over the
///   camera picture as it grows. RealityKit is Apple's current framework for camera
///   AR on iOS; the SceneKit view used by Explore (`ARSCNView`) belongs to SceneKit,
///   which Apple has deprecated as of iOS 26. Drawing the mesh ourselves in SceneKit
///   would also mean rebuilding geometry on every update; RealityKit does it for free.
/// - **The surface** arrives as "mesh anchors": the platform splits the world into
///   blocks about a metre across, each with its own small mesh, and keeps refining
///   them while the phone moves. `SweepReceiver` keeps the latest version of each on a
///   private background queue and reports counts to the screen.
/// - **Finish** pauses the session, then, still on that queue, copies every anchor's
///   corners and triangles into Core `MeshPart`s and merges them with Core's
///   `MeshAssembly` (moved into world positions, seams joined, empty faces dropped).
///   The result is y-up metres; `SweepCaptureService` turns it z-up and saves it.
@MainActor
final class ARKitSweepCapture: LiveSweepCapturing {
    private let receiver: SweepReceiver
    private let log: any Logging
    private var view: ARView?
    private var isRunning = false

    init(log: any Logging) {
        self.log = log
        receiver = SweepReceiver(log: log)
    }

    func start() -> SweepStreams {
        if isRunning {
            cancel()
        }
        let (progress, progressContinuation) = AsyncStream.makeStream(
            of: SweepProgress.self, bufferingPolicy: .bufferingNewest(1))
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        let streams = SweepStreams(progress: progress, statuses: statuses)

        guard ARWorldTrackingConfiguration.isSupported,
            ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        else {
            log.error("capture", "Sweep unsupported", ["reason": "scene reconstruction is not supported"])
            statusContinuation.yield(
                .unsupported(reason: "This phone has no LiDAR scanner, so sweep capture cannot run."))
            statusContinuation.finish()
            progressContinuation.finish()
            return streams
        }

        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .denied || permission == .restricted {
            log.warning("capture", "Camera permission denied", ["status": String(describing: permission.rawValue)])
            statusContinuation.yield(.permissionDenied)
            statusContinuation.finish()
            progressContinuation.finish()
            return streams
        }

        let configuration = ARWorldTrackingConfiguration()
        // `.mesh` builds triangles only; `.meshWithClassification` would also label
        // each face (wall, floor, seat…), which a scan of one subject does not need.
        configuration.sceneReconstruction = .mesh
        // Gravity is the platform's y axis, so "up" in the scan is truly up.
        configuration.worldAlignment = .gravity
        let session = cameraView().session
        session.delegate = receiver
        session.delegateQueue = receiver.queue
        receiver.begin(progress: progressContinuation, statuses: statusContinuation)
        statusContinuation.yield(.starting)
        // If the owner has not yet been asked, ARKit asks for camera permission here.
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
        isRunning = true
        log.info("capture", "Sweep session started", ["reconstruction": "mesh"])
        return streams
    }

    func finish() async throws -> Mesh {
        guard isRunning, let session = view?.session else { return .empty }
        isRunning = false
        // Pausing first means no anchor changes while the copy below is made.
        session.pause()
        let assembled = await receiver.assemble()
        log.info("capture", "Sweep mesh assembled", assembled.report.logDetails)
        return assembled.mesh
    }

    func cancel() {
        guard isRunning else { return }
        isRunning = false
        view?.session.pause()
        receiver.discard()
    }

    func makeCameraView() -> UIView {
        cameraView()
    }

    /// One `ARView` for the app's lifetime, made the first time it is needed. It owns
    /// the session, so the view and the capture always share it.
    private func cameraView() -> ARView {
        if let view {
            return view
        }
        let made = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        // Draws the reconstructed surface over the camera picture as it grows.
        made.debugOptions.insert(.showSceneUnderstanding)
        made.renderOptions.insert(.disableMotionBlur)
        made.backgroundColor = .black
        view = made
        return made
    }
}

/// Receives ARKit's callbacks on its own serial queue, keeps the latest mesh anchors and
/// turns them into Core values.
///
/// `@unchecked Sendable` is safe because every stored variable below is read and
/// written only on `queue`: ARKit calls the delegate methods there, and `begin`,
/// `discard` and `assemble` hop onto it before touching anything.
final class SweepReceiver: NSObject, @unchecked Sendable {
    /// Progress is sent at most this often, so the screen is not redrawn needlessly.
    static let progressInterval: TimeInterval = 0.25

    let queue = DispatchQueue(label: "com.nbs1997.scanlab.sweep", qos: .userInitiated)
    private let log: any Logging

    private var progress: AsyncStream<SweepProgress>.Continuation?
    private var statuses: AsyncStream<SensorStatus>.Continuation?
    private var anchors: [UUID: ARMeshAnchor] = [:]
    private var faceCount = 0
    private var tracking = SweepTracking.limited(.initialising)
    private var startTime: TimeInterval?
    private var lastSent: TimeInterval = -.infinity
    private var hasReportedRunning = false

    init(log: any Logging) {
        self.log = log
    }

    func begin(
        progress: AsyncStream<SweepProgress>.Continuation, statuses: AsyncStream<SensorStatus>.Continuation
    ) {
        queue.async { [self] in
            endStreams()
            self.progress = progress
            self.statuses = statuses
            anchors = [:]
            faceCount = 0
            tracking = .limited(.initialising)
            startTime = nil
            lastSent = -.infinity
            hasReportedRunning = false
        }
    }

    /// Throws away everything captured and ends the streams.
    func discard() {
        queue.async { [self] in
            log.info("capture", "Sweep session stopped", ["anchors": String(anchors.count), "kept": "no"])
            anchors = [:]
            endStreams()
        }
    }

    /// Copies every anchor's surface and merges them into one mesh, then forgets the
    /// anchors and ends the streams.
    func assemble() async -> AssembledMesh {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let parts = anchors.values.compactMap(Self.part(from:))
                let assembled = MeshAssembly.assemble(parts)
                log.info("capture", "Sweep session stopped", ["anchors": String(anchors.count), "kept": "yes"])
                anchors = [:]
                endStreams()
                continuation.resume(returning: assembled)
            }
        }
    }

    private func endStreams() {
        statuses?.yield(.stopped)
        statuses?.finish()
        progress?.finish()
        statuses = nil
        progress = nil
    }

    private func anchorsChanged(_ changed: [ARAnchor], removed: Bool) {
        for case let anchor as ARMeshAnchor in changed {
            anchors[anchor.identifier] = removed ? nil : anchor
        }
        faceCount = anchors.values.reduce(0) { $0 + $1.geometry.faces.count }
        sendProgress(force: false)
    }

    private func sendProgress(force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastSent >= Self.progressInterval else { return }
        lastSent = now
        let elapsed = startTime.map { now - $0 } ?? 0
        progress?.yield(
            SweepProgress(anchorCount: anchors.count, faceCount: faceCount, elapsed: elapsed, tracking: tracking))
    }

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

    static func tracking(for state: ARCamera.TrackingState) -> SweepTracking {
        switch state {
        case .normal:
            return .normal
        case .notAvailable:
            return .notAvailable
        case .limited(let reason):
            switch reason {
            case .initializing: return .limited(.initialising)
            case .excessiveMotion: return .limited(.movingTooFast)
            case .insufficientFeatures: return .limited(.tooLittleDetail)
            case .relocalizing: return .limited(.relocalising)
            @unknown default: return .limited(.other)
            }
        @unknown default:
            return .limited(.other)
        }
    }
}

extension SweepReceiver: ARSessionDelegate {
    // These methods run on `queue` (the session's delegate queue). They are marked
    // `nonisolated` so Swift does not assume they run on the main thread.

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Only the first frame matters here: it means the camera is running. The frame
        // itself is not kept, because holding frames stalls the camera.
        guard !hasReportedRunning, progress != nil else { return }
        hasReportedRunning = true
        startTime = ProcessInfo.processInfo.systemUptime
        statuses?.yield(.running)
        log.info("capture", "First frame received")
        sendProgress(force: true)
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchorsChanged(anchors, removed: false)
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        anchorsChanged(anchors, removed: false)
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        anchorsChanged(anchors, removed: true)
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let next = Self.tracking(for: camera.trackingState)
        guard next != tracking else { return }
        tracking = next
        log.info("capture", "Tracking changed", ["state": next.logName])
        sendProgress(force: true)
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        if let arError = error as? ARError, arError.code == .cameraUnauthorized {
            log.warning("capture", "Camera permission denied", ["status": "refused when asked"])
            statuses?.yield(.permissionDenied)
        } else {
            log.error("capture", "Sweep session failed", ["reason": error.localizedDescription])
            statuses?.yield(.failed(reason: error.localizedDescription))
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        log.warning("capture", "Sweep session interrupted")
        statuses?.yield(.interrupted)
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        log.info("capture", "Sweep session resumed")
        statuses?.yield(.running)
    }
}
