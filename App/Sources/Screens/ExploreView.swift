import ScanLabCore
import SwiftUI
import UIKit

/// Mockups screen 6, Explore live: the camera picture with depth and confidence layers,
/// the distance at the centre and the frame rate (US-03, FR-2.1, FR-2.2, NFR-7).
struct ExploreView: View {
    @State var model: ExploreModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Sideways on an iPhone gives a compact height; controls then move to the
    /// trailing edge (interaction-spec.md, "Orientation").
    private var isSideways: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            LiveLayers(model: model)
                .ignoresSafeArea()
            if isSideways {
                HStack(alignment: .top) {
                    ReadoutPanel(model: model)
                    Spacer()
                    LayerControls(model: model, isSideways: true)
                }
                .padding()
            } else {
                VStack {
                    ReadoutPanel(model: model)
                    Spacer()
                    LayerControls(model: model, isSideways: false)
                }
                .padding()
            }
            StatusMessage(status: model.status)
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.showCamera) { _, isOn in model.layerChanged(.camera, isOn: isOn) }
        .onChange(of: model.showDepth) { _, isOn in model.layerChanged(.depth, isOn: isOn) }
        .onChange(of: model.showConfidence) { _, isOn in model.layerChanged(.confidence, isOn: isOn) }
    }
}

/// The full-screen picture: camera underneath, then depth, then confidence.
///
/// ARKit fills the camera view by scaling the picture up until it covers the screen
/// and trimming the overflow ("aspect fill"), centred. The overlays have the same
/// shape as the camera picture (4 : 3) and are already turned the same way, so
/// filling the same rectangle the same way puts every overlay pixel over the part of
/// the picture it measured.
private struct LiveLayers: View {
    let model: ExploreModel

    var body: some View {
        ZStack {
            Color.black
            CameraPreview(feed: model.feed) { orientation in
                model.interfaceOrientationChanged(orientation)
            }
            .opacity(model.showCamera ? 1 : 0)
            .accessibilityHidden(true)
            if model.showDepth, let image = model.depthImage {
                OverlayImage(image: image, opacity: model.showCamera ? 0.6 : 1)
            }
            if model.showConfidence, let image = model.confidenceImage {
                OverlayImage(image: image, opacity: model.showCamera || model.showDepth ? 0.5 : 1)
            }
            CentreMark()
        }
    }
}

/// One overlay picture, filling the space the same way the camera picture does.
private struct OverlayImage: View {
    let image: CGImage
    let opacity: Double

    var body: some View {
        // The clear colour takes exactly the space offered; the picture is drawn over
        // it, overflowing as needed, then trimmed. Without this, the overflowing
        // picture would push the whole screen's layout wider.
        Color.clear
            .overlay {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            }
            .clipped()
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}

/// A small ring at the centre, showing where the distance is measured.
private struct CentreMark: View {
    var body: some View {
        Circle()
            .stroke(.white, lineWidth: 2)
            .frame(width: 28, height: 28)
            .shadow(color: .black.opacity(0.6), radius: 2)
            .accessibilityHidden(true)
    }
}

/// Distance at the centre, frame rate, and the legend for whichever layers are on.
private struct ReadoutPanel: View {
    let model: ExploreModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.centreText)
                        .font(.title2.weight(.semibold).monospacedDigit())
                    Text("at centre").font(.caption)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Distance at centre")
                .accessibilityValue(model.centreSpoken)

                Text(model.frameRateText)
                    .font(.callout.monospacedDigit())
                    .accessibilityLabel("Frame rate")
                    .accessibilityValue(model.frameRateSpoken)
            }
            if model.showDepth {
                DepthLegend(map: model.depthColours)
            }
            if model.showConfidence {
                ConfidenceLegend(map: model.confidenceColours)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// The colour ramp with distances beneath (accessibility check A8).
private struct DepthLegend: View {
    let map: DepthColourMap

    var body: some View {
        let stops = map.legendStops(count: 5)
        VStack(alignment: .leading, spacing: 2) {
            LinearGradient(colors: stops.map { Color(rgba: $0.colour) }, startPoint: .leading, endPoint: .trailing)
                .frame(width: 200, height: 10)
                .clipShape(Capsule())
            HStack {
                Text("Near \(ReadoutText.legendDistance(metres: map.nearMetres))")
                Spacer()
                Text("Far \(ReadoutText.legendDistance(metres: map.farMetres))")
            }
            .font(.caption2)
            .frame(width: 200)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Depth colours")
        .accessibilityValue(
            "Red is near, \(ReadoutText.legendDistance(metres: map.nearMetres)). "
                + "Blue is far, \(ReadoutText.legendDistance(metres: map.farMetres)). Grey is no reading.")
    }
}

private struct ConfidenceLegend: View {
    let map: ConfidenceColourMap

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ConfidenceLevel.allCases, id: \.self) { level in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(rgba: map.colour(for: level)))
                        .frame(width: 10, height: 10)
                    Text(level.name)
                }
            }
        }
        .font(.caption2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence colours")
        .accessibilityValue("Red is low, amber is medium, green is high.")
    }
}

/// The four layer toggles. Edges is shown but disabled until edge detection arrives.
private struct LayerControls: View {
    @Bindable var model: ExploreModel
    let isSideways: Bool

    var body: some View {
        VStack(alignment: isSideways ? .trailing : .center, spacing: 6) {
            if isSideways {
                VStack(alignment: .trailing, spacing: 8) { toggles }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { toggles }
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            toggle(.camera, isOn: $model.showCamera)
                            toggle(.depth, isOn: $model.showDepth)
                        }
                        GridRow {
                            toggle(.confidence, isOn: $model.showConfidence)
                            edgesToggle
                        }
                    }
                }
            }
            Text("Edges: \(ExploreModel.edgesUnavailableReason.lowercased())")
                .font(.caption2)
                .accessibilityHidden(true)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var toggles: some View {
        toggle(.camera, isOn: $model.showCamera)
        toggle(.depth, isOn: $model.showDepth)
        toggle(.confidence, isOn: $model.showConfidence)
        edgesToggle
    }

    private var edgesToggle: some View {
        toggle(.edges, isOn: .constant(false))
            .disabled(true)
            .accessibilityHint(ExploreModel.edgesUnavailableReason)
    }

    private func toggle(_ layer: ExploreLayer, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(layer.rawValue, systemImage: Self.symbol(for: layer))
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .accessibilityLabel("\(layer.rawValue) layer")
    }

    private static func symbol(for layer: ExploreLayer) -> String {
        switch layer {
        case .camera: "camera"
        case .depth: "square.3.layers.3d"
        case .confidence: "checkmark.seal"
        case .edges: "square.dashed"
        }
    }
}

/// Starting, permission refused, unsupported, failed or paused (interaction-spec.md).
private struct StatusMessage: View {
    let status: SensorStatus
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch status {
        case .starting:
            ProgressView("Starting camera")
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .permissionDenied:
            ContentUnavailableView {
                Label("Camera not allowed", systemImage: "video.slash")
            } description: {
                Text(status.message ?? "")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .background(.regularMaterial)
        case .unsupported, .failed:
            ContentUnavailableView(
                "Live view unavailable", systemImage: "exclamationmark.triangle",
                description: Text(status.message ?? "")
            )
            .background(.regularMaterial)
        case .interrupted:
            Text(status.message ?? "")
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .running, .stopped:
            EmptyView()
        }
    }
}

extension Color {
    /// A SwiftUI colour from a Core colour.
    init(rgba colour: RGBAColour) {
        self.init(
            .sRGB, red: Double(colour.red) / 255, green: Double(colour.green) / 255,
            blue: Double(colour.blue) / 255, opacity: Double(colour.alpha) / 255)
    }
}

#Preview {
    NavigationStack {
        ExploreView(model: ExploreModel(environment: .preview()))
    }
}
