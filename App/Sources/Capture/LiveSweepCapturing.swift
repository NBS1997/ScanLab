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
        progressContinuation.yield(SweepProgress(anchorCount: 4, faceCount: 12_480, elapsed: 12))
        progressContinuation.finish()
        return SweepStreams(progress: progress, statuses: statuses)
    }

    func finish() async throws -> Mesh {
        SampleMeshes.stepBlock()
    }

    func cancel() {}

    func makeCameraView() -> UIView {
        let view = UIView()
        view.backgroundColor = .darkGray
        return view
    }
}
