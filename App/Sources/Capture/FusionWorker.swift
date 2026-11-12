import Foundation
import ScanLabCore

/// Runs Core's `DepthFusion` on its own background queue during a sweep (U14, DF-5,
/// NFR-F1).
///
/// The camera delivers depth pictures far faster than they can be fused. The sweep
/// receiver hands over one picture at a time and skips pictures while one is still
/// being fused, so the camera never waits for this queue.
///
/// `@unchecked Sendable` is safe because `fusion` and `busySeconds` are only read and
/// written inside blocks running on `queue`, one at a time.
final class FusionWorker: @unchecked Sendable {
    /// What fusion produced at Finish, with the numbers the diagnostics log needs (DF-10).
    struct Outcome: Sendable {
        let fused: FusedMesh
        let stats: FusionStats
        /// Average time spent fusing one picture.
        let averageMilliseconds: Double
        /// Time spent drawing the surface at Finish.
        let extractionSeconds: Double
        /// Pictures that arrived while another was being fused (DF-5).
        var skippedPictures = 0

        var logDetails: [String: String] {
            [
                "pictures": String(stats.framesFused),
                "skipped": String(skippedPictures),
                "rejected": String(stats.framesRejected),
                "readings": String(stats.readingsUsed),
                "blocks": String(stats.blocks),
                "full": stats.isFull ? "yes" : "no",
                "ms per picture": String(format: "%.1f", averageMilliseconds),
                "extract s": String(format: "%.2f", extractionSeconds),
                "pieces dropped": String(fused.piecesDropped),
                "faces": String(fused.mesh.faceCount),
            ]
        }
    }

    private let queue = DispatchQueue(label: "com.nbs1997.scanlab.fusion", qos: .userInitiated)
    private var fusion = DepthFusion()
    private var busySeconds = 0.0

    /// Throws away anything fused and starts again with `settings`, fusing only inside
    /// `region` when one is given (the subject box, SB-7).
    func reset(settings: FusionSettings = .standard, region: Box? = nil) {
        queue.async { [self] in
            fusion = DepthFusion(settings: settings, region: region)
            busySeconds = 0
        }
    }

    /// Fuses one picture in the background, then calls `done` (on the fusion queue)
    /// with the updated counts.
    func integrate(_ frame: FusionFrame, done: @escaping @Sendable (FusionStats) -> Void) {
        queue.async { [self] in
            let start = ProcessInfo.processInfo.systemUptime
            fusion.integrate(frame)
            busySeconds += ProcessInfo.processInfo.systemUptime - start
            done(fusion.stats)
        }
    }

    /// Waits for any picture still being fused, draws the surface and frees the memory.
    func finish() async -> Outcome {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let start = ProcessInfo.processInfo.systemUptime
                let fused = fusion.makeMesh()
                let extraction = ProcessInfo.processInfo.systemUptime - start
                let stats = fusion.stats
                let average = stats.framesFused > 0 ? busySeconds / Double(stats.framesFused) * 1_000 : 0
                fusion = DepthFusion(settings: fusion.settings, region: fusion.region)
                busySeconds = 0
                continuation.resume(
                    returning: Outcome(
                        fused: fused, stats: stats, averageMilliseconds: average, extractionSeconds: extraction))
            }
        }
    }
}
