import Foundation
import ScanLabCore
import UIKit

/// The app's view of sweep capture: Core's `SweepCapturing` port, plus a view that
/// shows the camera with the growing mesh drawn over it. The view stays on the app
/// side because it is a platform object Core must not know about (ADR-003).
protocol LiveSweepCapturing: SweepCapturing {
    /// A view that draws the camera picture and the reconstructed surface, filling its
    /// bounds.
    @MainActor func makeCameraView() -> UIView

    /// Finds the subject under a tap on the camera view (SB-2). `point` is in the view's
    /// own points; `viewSize` is the view's size.
    @MainActor func pickSubject(
        atViewPoint point: CGPoint, viewSize: CGSize
    ) async -> Result<SubjectBox, SubjectPickError>

    /// Draws `box` over the camera (yellow, or green when locked), or removes it (SB-6).
    @MainActor func showSubject(_ box: SubjectBox?, locked: Bool)

    /// Starts fusing inside `box`, or over the whole view when it is nil (SB-1, SB-7).
    @MainActor func beginScanning(in box: SubjectBox?)
}

/// A stand-in for SwiftUI previews: no camera; reports a little progress and finishes
/// with the sample block.
@MainActor
final class PreviewSweepCapture: LiveSweepCapturing {
    func start() -> SweepStreams {
        let (progress, progressContinuation) = AsyncStream.makeStream(of: SweepProgress.self)
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        statusContinuation.yield(.running)
        statusContinuation.finish()
        progressContinuation.yield(SweepProgress(anchorCount: 4, faceCount: 12_480, elapsed: 12, fusedFrames: 48))
        progressContinuation.finish()
        return SweepStreams(progress: progress, statuses: statuses)
    }

    func finish() async throws -> Mesh {
        SampleMeshes.stepBlock()
    }

    func cancel() {}

    func pickSubject(atViewPoint point: CGPoint, viewSize: CGSize) async -> Result<SubjectBox, SubjectPickError> {
        .success(SubjectBox(bounds: Box(minimum: .zero, maximum: Vec3(0.1, 0.08, 0.12)), floorHeight: 0))
    }

    func showSubject(_ box: SubjectBox?, locked: Bool) {}

    func beginScanning(in box: SubjectBox?) {}

    func makeCameraView() -> UIView {
        let view = UIView()
        view.backgroundColor = .darkGray
        return view
    }
}
