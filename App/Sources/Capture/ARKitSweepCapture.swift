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
/// - **The detailed model** (U14, ADR-029) comes from the LiDAR's own depth pictures,
///   not from that coarse room-scale surface. While tracking is normal, each depth
///   picture, with the camera's position and lens numbers, is handed to a
///   `FusionWorker`, which fuses it into Core's `DepthFusion` grid in the background.
/// - **Finish** pauses the session, merges the platform's pieces with Core's
///   `MeshAssembly` (kept as a fallback), then asks the worker to draw the fused
///   surface. The fused model is returned unless fusion produced nothing (DF-7). Both
///   are y-up metres; `SweepCaptureService` turns the result z-up and saves it.
@MainActor
final class ARKitSweepCapture: LiveSweepCapturing {
    private let receiver: SweepReceiver
    private let log: any Logging
    private var view: ARView?
    private var isRunning = false
    /// The subject box drawn over the camera, if any (SB-6).
    private var outline: AnchorEntity?

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
        // Depth pictures for fusion (U14). Every LiDAR phone supports this; if not, the
        // sweep still works and falls back to the scene mesh (DF-7).
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        } else {
            log.warning("capture", "Depth pictures unsupported", ["fallback": "scene mesh"])
        }
        let session = cameraView().session
        session.delegate = receiver
        session.delegateQueue = receiver.queue
        receiver.begin(progress: progressContinuation, statuses: statusContinuation)
        statusContinuation.yield(.starting)
        // If the owner has not yet been asked, ARKit asks for camera permission here.
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
        isRunning = true
        log.info("capture", "Sweep session started", ["reconstruction": "mesh", "fusion": "depth pictures"])
        return streams
    }

    func finish() async throws -> Mesh {
        guard isRunning, let session = view?.session else { return .empty }
        isRunning = false
        showSubject(nil, locked: false)
        // Pausing first means no anchor changes while the copy below is made.
        session.pause()
        let assembled = await receiver.assemble()
        log.info("capture", "Sweep mesh assembled", assembled.report.logDetails)
        let outcome = await receiver.finishFusion()
        log.info("capture", "Fusion finished", outcome.logDetails)
        let sceneFaces = String(assembled.mesh.faceCount)
        guard !outcome.fused.mesh.isEmpty else {
            log.warning(
                "capture", "Sweep model chosen",
                ["source": "scene mesh", "reason": "fusion produced no surface", "faces": sceneFaces])
            return assembled.mesh
        }
        let fusedFaces = String(outcome.fused.mesh.faceCount)
        log.info(
            "capture", "Sweep model chosen",
            ["source": "depth fusion", "faces": fusedFaces, "scene mesh faces": sceneFaces])
        return outcome.fused.mesh
    }

    func cancel() {
        guard isRunning else { return }
        isRunning = false
        showSubject(nil, locked: false)
        view?.session.pause()
        receiver.discard()
    }

    // MARK: - Subject box (U09 part 1)

    func pickSubject(atViewPoint point: CGPoint, viewSize: CGSize) async -> Result<SubjectBox, SubjectPickError> {
        guard isRunning, let view, viewSize.width > 0, viewSize.height > 0 else { return .failure(.notReady) }
        let orientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let fraction = CGPoint(x: point.x / viewSize.width, y: point.y / viewSize.height)
        return await receiver.picker.pick(viewPoint: fraction, viewport: viewSize, orientation: orientation)
    }

    func showSubject(_ box: SubjectBox?, locked: Bool) {
        outline?.removeFromParent()
        outline = nil
        guard let box, let view else { return }
        let made = SubjectBoxOutline.make(for: box, locked: locked)
        view.scene.addAnchor(made)
        outline = made
    }

    func beginScanning(in box: SubjectBox?) {
        guard isRunning else { return }
        receiver.beginScanning(in: box)
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
