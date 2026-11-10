import SwiftUI
import UIKit

/// Shows the feed's live camera picture in SwiftUI, and reports which way the phone
/// is held so the depth and confidence overlays can be turned to match.
struct CameraPreview: UIViewRepresentable {
    let feed: any LiveCameraFeeding
    let onOrientationChange: @MainActor @Sendable (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> CameraContainerView {
        let container = CameraContainerView(content: feed.makeCameraView())
        container.onOrientationChange = onOrientationChange
        return container
    }

    func updateUIView(_ view: CameraContainerView, context: Context) {
        view.onOrientationChange = onOrientationChange
    }
}

/// Holds the camera view and notices rotation. When the phone turns, the view is laid
/// out again at its new size, so `layoutSubviews` is a reliable place to check.
final class CameraContainerView: UIView {
    var onOrientationChange: (@MainActor @Sendable (UIInterfaceOrientation) -> Void)?
    private var lastReported: UIInterfaceOrientation?

    init(content: UIView) {
        super.init(frame: .zero)
        backgroundColor = .black
        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportOrientation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportOrientation()
    }

    private func reportOrientation() {
        guard let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation,
            orientation != lastReported
        else { return }
        lastReported = orientation
        // Passed on after this layout pass finishes: SwiftUI does not allow its state
        // to change while it is laying out views.
        let callback = onOrientationChange
        Task { @MainActor in
            callback?(orientation)
        }
    }
}
