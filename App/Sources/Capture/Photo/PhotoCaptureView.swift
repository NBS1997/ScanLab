import RealityKit
import ScanLabCore
import SwiftUI

/// The Photos capture screen (mockups screen 3 for the Photos method; US-07): Apple's
/// guided capture view with ScanLab's buttons under it, then building with progress,
/// then the keep-or-discard question for the raw capture.
///
/// This is the entry point New scan opens for the Photos method:
/// `PhotoCaptureView(environment: environment)`. It is full-screen and is left by
/// Close or Done.
struct PhotoCaptureView: View {
    @State private var model: PhotoCaptureModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingClose = false

    init(environment: AppEnvironment) {
        _model = State(initialValue: PhotoCaptureModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Photo scan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.flow.isFinished ? "Done" : "Close") { close() }
                            .accessibilityHint("Leaves the photo scan")
                    }
                }
                .confirmationDialog(
                    "Stop building?", isPresented: $confirmingClose, titleVisibility: .visible
                ) {
                    Button("Stop and close", role: .destructive) { dismiss() }
                    Button("Keep building", role: .cancel) {}
                } message: {
                    Text("The photos are kept. Open Photos again to build them.")
                }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            model.scenePhaseChanged(to: phase)
        }
    }

    /// Closing mid-build asks first; anything else just closes.
    private func close() {
        if model.flow.buildFraction != nil {
            confirmingClose = true
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let leftover = model.unfinished {
            UnfinishedCaptureCard(capture: leftover, build: model.buildUnfinished, discard: model.discardUnfinished)
        } else {
            switch model.flow.phase {
            case .preparing:
                ProgressView("Starting camera…")
            case .capturing, .finishingCapture:
                GuidedCaptureArea(model: model)
            case .readyToBuild, .building, .saving:
                BuildingPanel(model: model)
            case .askingToKeep(let offer):
                KeepPanel(offer: offer, model: model)
            case .done(let outcome):
                FinishedPanel(model: model, symbol: "checkmark.circle", title: "Photo scan saved") {
                    Text(PhotoBuildText.done(outcome))
                    Text(PhotoBuildText.detail(model.detailLevel))
                }
            case .failed(let error, let canBuildAgain):
                FinishedPanel(model: model, symbol: "exclamationmark.triangle", title: "Photo scan stopped") {
                    Text(error.localizedDescription)
                } actions: {
                    if canBuildAgain && model.hasCaptureOnDisk {
                        Button("Build again", systemImage: "arrow.clockwise") { model.startBuild() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("Builds the model again from the same photos")
                    }
                }
            case .cancelled(let canBuildAgain):
                FinishedPanel(model: model, symbol: "xmark.circle", title: "Cancelled") {
                    Text(canBuildAgain ? "The photos are kept." : "The capture was removed.")
                } actions: {
                    if canBuildAgain && model.hasCaptureOnDisk {
                        Button("Build again", systemImage: "arrow.clockwise") { model.startBuild() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

/// The platform's guided capture view, with prompts and ScanLab's buttons beneath.
private struct GuidedCaptureArea: View {
    let model: PhotoCaptureModel

    var body: some View {
        VStack(spacing: 0) {
            if let session = model.session {
                ObjectCaptureView(session: session)
                    .accessibilityLabel("Camera view")
                    .accessibilityHint("Shows what is being photographed")
            } else {
                ProgressView("Saving the last photos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            controls
                .padding()
                .background(.bar)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if let advice = model.feedbackText {
                Text(advice)
                    .font(.headline)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if case .capturing(let shots) = model.flow.phase {
                Text(PhotoBuildText.photos(shots))
                    .monospacedDigit()
                    .accessibilityLabel("Photos taken: \(shots)")
            }
            if let hint = model.detectHint {
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            buttons
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Cancel", role: .cancel) { model.cancel() }
                .buttonStyle(.bordered)
                .accessibilityHint("Stops the capture and removes its photos")
            switch model.step {
            case .starting, .finishing:
                EmptyView()
            case .lookingForObject:
                Button("Find object") { model.retryDetecting() }
                    .buttonStyle(.bordered)
                Button("Start without box") { model.startCapturing() }
                    .buttonStyle(.borderedProminent)
            case .objectFound:
                Button("Start capture") { model.startCapturing() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Starts taking photos. Walk slowly all the way round the object.")
            case .capturing:
                if model.scanPassComplete {
                    Button("Another pass") { model.anotherPass() }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Goes round again at a different height")
                }
                Button("Finish") { model.finishCapture() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Stops taking photos and builds the model")
            }
        }
    }
}

/// Building progress (FR-4.3): the bar, the stage, the time left, a note when no
/// update has come for 10 seconds, and the detail level (FR-4.2).
private struct BuildingPanel: View {
    let model: PhotoCaptureModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            switch model.flow.phase {
            case .building(let progress):
                // Redraws every second so the "still working" note appears on time.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    progressView(progress, now: context.date)
                }
                Button("Cancel", role: .cancel) { model.cancel() }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Stops building. The photos are kept, so you can build again.")
            case .saving:
                ProgressView("Saving the scan…")
            default:
                ProgressView("Getting ready to build…")
            }
            Text(PhotoBuildText.detail(model.detailLevel))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let note = model.backgroundNote {
                Label(note, systemImage: "moon.zzz")
                    .font(.footnote)
            }
            Text("You can switch to another app; what happens to the build is recorded in Diagnostics.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private func progressView(_ progress: BuildProgress, now: Date) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: progress.fraction) {
                Text(PhotoBuildText.headline(progress))
                    .font(.headline)
            } currentValueLabel: {
                Text(PhotoBuildText.stage(progress.stage))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Building model")
            .accessibilityValue(PhotoBuildText.spoken(progress))
            if let left = PhotoBuildText.remaining(progress.secondsRemaining) {
                Text(left)
                    .font(.callout)
            }
            if let stale = PhotoBuildText.staleNotice(progress, now: now) {
                Text(stale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The keep-or-discard question, with the storage it uses (FR-6.6).
private struct KeepPanel: View {
    let offer: KeepOffer
    let model: PhotoCaptureModel
    @State private var working = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text(PhotoBuildText.keepTitle)
                .font(.title2.bold())
            Text(PhotoBuildText.keepMessage(offer))
                .multilineTextAlignment(.center)
            Text(PhotoBuildText.detail(model.detailLevel))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                working = true
                Task {
                    await model.keepRawCapture()
                    working = false
                }
            } label: {
                Text(PhotoBuildText.keepButton(offer))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Keeps the photos and camera positions with the scan, to export later")
            Button("Discard", role: .destructive) { model.discardRawCapture() }
                .buttonStyle(.bordered)
                .accessibilityHint("Removes the photos to free the space. The model is kept.")
            Spacer()
        }
        .disabled(working)
        .padding()
    }
}

/// A capture left from earlier, offered before a new capture starts (FR-4.3).
private struct UnfinishedCaptureCard: View {
    let capture: UnfinishedCapture
    let build: @MainActor () -> Void
    let discard: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("Unfinished capture")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
            Button("Build it now", systemImage: "hammer", action: build)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Builds a model from these photos without capturing again")
            Button("Discard it", role: .destructive, action: discard)
                .buttonStyle(.bordered)
                .accessibilityHint("Removes these photos, then starts a new capture")
            Spacer()
        }
        .padding()
    }

    /// "40 photos from 11 Nov 2026 at 2:05 pm, using 412 MB, have not been built yet."
    private var message: String {
        let when = capture.modified.formatted(date: .abbreviated, time: .shortened)
        let size = Units.storage(capture.bytes)
        return "\(PhotoBuildText.photos(capture.images)) from \(when), using \(size), have not been built yet."
    }
}

/// The end of a capture: what happened, any action, and the button to leave.
private struct FinishedPanel<Message: View, Actions: View>: View {
    let model: PhotoCaptureModel
    let symbol: String
    let title: String
    let message: Message
    let actions: Actions
    @Environment(\.dismiss) private var dismiss

    init(
        model: PhotoCaptureModel, symbol: String, title: String, @ViewBuilder message: () -> Message,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.model = model
        self.symbol = symbol
        self.title = title
        self.message = message()
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: symbol)
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
            VStack(spacing: 8) { message }
                .multilineTextAlignment(.center)
            if let note = model.backgroundNote {
                Label(note, systemImage: "moon.zzz")
                    .font(.footnote)
            }
            actions
            if model.hasCaptureOnDisk && !isDone {
                Button("Discard capture", role: .destructive) { model.discardCapture() }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Removes the photos from this phone")
            }
            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    private var isDone: Bool {
        if case .done = model.flow.phase { return true }
        return false
    }
}

#Preview {
    PhotoCaptureView(environment: .preview())
}
