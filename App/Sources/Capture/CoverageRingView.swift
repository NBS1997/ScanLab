import ScanLabCore
import SwiftUI

/// The coverage dome seen from above (CD-3): three rings of 8 patches. The middle ring
/// is looking down from above, the outer ring is the sides. Covered patches are green;
/// the patch the camera is in now is outlined in white.
struct CoverageRingView: View {
    let summary: CoverageSummary

    /// Inner and outer radius of each ring, in points; ring 0 (the side) is outermost.
    private static let radii: [(inner: CGFloat, outer: CGFloat)] = [(44, 58), (29, 42), (14, 27)]

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            for patch in summary.covered.indices {
                let ring = patch / CoverageDome.stepsRound
                let step = patch % CoverageDome.stepsRound
                guard ring < Self.radii.count else { continue }
                let path = Self.sector(
                    centre: centre, radii: Self.radii[ring], step: step, steps: CoverageDome.stepsRound)
                context.fill(path, with: .color(summary.covered[patch] ? .green : .white.opacity(0.25)))
                if patch == summary.current {
                    context.stroke(path, with: .color(.white), lineWidth: 2.5)
                }
            }
        }
        .frame(width: 124, height: 124)
        .padding(6)
        .background(.ultraThinMaterial, in: Circle())
        .accessibilityElement()
        .accessibilityLabel("Coverage")
        .accessibilityValue(summary.spoken)
    }

    /// One patch: the slice of a ring between two angles.
    private static func sector(
        centre: CGPoint, radii: (inner: CGFloat, outer: CGFloat), step: Int, steps: Int
    ) -> Path {
        let width = 360.0 / Double(steps)
        // A small gap between patches keeps them readable.
        let start = Angle.degrees(Double(step) * width + 1.5)
        let end = Angle.degrees(Double(step + 1) * width - 1.5)
        var path = Path()
        path.addArc(center: centre, radius: radii.outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: centre, radius: radii.inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
