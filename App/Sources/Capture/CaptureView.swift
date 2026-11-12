import ScanLabCore
import SwiftUI
import UIKit

/// Mockups screen 3, Capture (US-06, FR-3.1–3.3): full-screen camera with the surface
/// drawn over it as it grows, a timer, the number of areas and faces, a prompt when
/// tracking is limited, Close and Finish. It is modal: it is left only by Finish or
/// Close (interaction-spec.md). Guidance with haptics, tones and coverage arrives with
/// unit U09.
struct CaptureView: View {
    @State var model: CaptureModel
    /// Called once the capture is over: with the new scan's identity, or nil when
    /// nothing was saved.
    let onDone: (UUID?) -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var confirmingClose = false

    /// Sideways on an iPhone gives a compact height; controls then move to the
    /// trailing edge (interaction-spec.md, "Orientation").
    private var isSideways: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            SweepCameraView(capture: model.capture)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            if model.acceptsSubjectTaps {
                subjectTapLayer
            }
            if isSideways {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        topBar
                        Spacer()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Spacer()
                        bottomControls
                    }
                }
                .padding()
            } else {
                VStack {
                    topBar
                    Spacer()
                    bottomControls
                }
                .padding()
            }
            if let prompt = model.prompt {
                PromptBanner(text: prompt)
            }
            CaptureStateOverlay(model: model, onDone: onDone)
        }
        .statusBarHidden()
        // A success buzz the first time every direction is covered (CD-5).
        .sensoryFeedback(.success, trigger: model.coverage?.isComplete ?? false) { wasComplete, isComplete in
            !wasComplete && isComplete
        }
        .onAppear { model.start() }
        .onDisappear { model.screenGone() }
        .onChange(of: model.phase) { _, phase in
            if case .saved(let id) = phase {
                onDone(id)
            }
        }
        .confirmationDialog(
            "Discard this capture?", isPresented: $confirmingClose, titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { close() }
            Button("Keep capturing", role: .cancel) {}
        } message: {
            Text("What has been captured so far will not be saved.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if model.progress.faceCount > 0 && model.phase == .capturing {
                    confirmingClose = true
                } else {
                    close()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())
            .disabled(model.phase == .finishing)
            .accessibilityLabel("Close")
            .accessibilityHint("Ends the capture without saving")

            ElapsedLabel(since: model.capturingSince)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            if !isSideways {
                Spacer()
            }
        }
    }

    /// Catches taps on the camera picture while choosing the subject (SB-2). The tap's
    /// position is in the same points as the camera view, which also fills the screen.
    private var subjectTapLayer: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    Task { await model.tapped(at: location, in: geometry.size) }
                }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Camera picture")
        .accessibilityHint("Tap the part you want to scan, or choose Scan everything")
    }

    /// While choosing: the box controls. While scanning: coverage, counts and Finish.
    @ViewBuilder
    private var bottomControls: some View {
        if model.choice.isScanning {
            if let coverage = model.coverage {
                CoverageRingView(summary: coverage)
            }
            stats
            finishButton
        } else if model.phase == .capturing {
            subjectControls
        }
    }

    private var subjectControls: some View {
        VStack(spacing: 10) {
            if case .proposed = model.choice.stage {
                HStack(spacing: 10) {
                    controlButton("Smaller") { model.resize(by: 0.9) }
                    controlButton("Bigger") { model.resize(by: 1.1) }
                }
                Button {
                    model.lockSubject()
                } label: {
                    Text("Scan this")
                        .font(.headline)
                        .frame(minWidth: 160, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Scans only what is inside the yellow box")
            }
            controlButton("Scan everything") { model.scanEverything() }
                .accessibilityHint("Scans the whole view without a box")
        }
    }

    private func controlButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var stats: some View {
        Text(model.statsText)
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel("Captured")
            .accessibilityValue(model.statsText)
    }

    private var finishButton: some View {
        Button {
            Task { await model.finish() }
        } label: {
            Text("Finish")
                .font(.headline)
                .frame(minWidth: 160, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canFinish)
        .accessibilityHint(model.canFinish ? "Saves the scan to the library" : "Available once a surface appears")
    }

    private func close() {
        model.cancel()
        onDone(nil)
    }
}

/// "00:42 · Sweep", counting up once a second while capturing.
private struct ElapsedLabel: View {
    let since: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = since.map { context.date.timeIntervalSince($0) } ?? 0
            Text("\(CaptureText.elapsed(seconds)) · Sweep")
                .font(.callout.monospacedDigit())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sweep capture time")
                .accessibilityValue(CaptureText.spokenElapsed(seconds))
        }
    }
}

/// The tracking prompt, near the top centre so it does not cover the subject.
private struct PromptBanner: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.black)
                .padding(.top, 72)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
        }
        .padding(.horizontal)
    }
}

/// Starting, saving, and every way a capture can fail (interaction-spec.md, states
/// table), drawn over the camera.
private struct CaptureStateOverlay: View {
    let model: CaptureModel
    let onDone: (UUID?) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch model.phase {
        case .idle, .preparing:
            ProgressView("Starting camera")
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .finishing:
            VStack(spacing: 8) {
                ProgressView("Saving scan…")
                Text("Joining \(model.statsText.lowercased())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        case .failed(let error):
            failure(error)
        case .capturing, .saved, .cancelled:
            EmptyView()
        }
    }

    @ViewBuilder
    private func failure(_ error: CaptureError) -> some View {
        ContentUnavailableView {
            Label(Self.title(for: error), systemImage: Self.symbol(for: error))
        } description: {
            Text(error.errorDescription ?? "")
        } actions: {
            switch error {
            case .permissionDenied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            case .sensorUnavailable:
                EmptyView()
            default:
                Button("Try again") { model.start() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Close") { onDone(nil) }
        }
        .background(.regularMaterial)
    }

    private static func title(for error: CaptureError) -> String {
        switch error {
        case .permissionDenied: "Camera not allowed"
        case .sensorUnavailable: "Sweep unavailable"
        case .nothingCaptured: "Nothing captured"
        case .noSpace: "Not enough space"
        case .sessionFailed, .saveFailed, .buildFailed: "Scan not saved"
        }
    }

    private static func symbol(for error: CaptureError) -> String {
        switch error {
        case .permissionDenied: "video.slash"
        case .noSpace: "externaldrive.badge.exclamationmark"
        case .nothingCaptured: "cube.transparent"
        default: "exclamationmark.triangle"
        }
    }
}

/// Shows the capture's camera view (with the growing surface) in SwiftUI.
private struct SweepCameraView: UIViewRepresentable {
    let capture: any LiveSweepCapturing

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        let content = capture.makeCameraView()
        // The camera view is reused between captures; take it from any earlier screen.
        content.removeFromSuperview()
        content.frame = container.bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(content)
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {}
}

#Preview {
    CaptureView(model: CaptureModel(environment: .preview())) { _ in }
}
