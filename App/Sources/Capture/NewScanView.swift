import ScanLabCore
import SwiftUI

/// Places the library's navigation can go besides a scan (whose identity is its own
/// destination).
enum LibraryDestination: Hashable {
    case newScan
}

/// Mockups screen 2, New scan (US-06, US-07): the two capture methods, each with a
/// one-line "use this for", and a surface tip. Sweep opens the Capture screen; Photos
/// opens the photo capture screen once that build is merged.
struct NewScanView: View {
    /// Builds the photo capture screen (unit U08). Nil until the photo capture build is
    /// merged: the Photos row is then shown greyed out with `photosUnavailableReason`.
    typealias PhotoCaptureScreen = () -> AnyView

    static let photosUnavailableReason = "Comes in the photo capture build"
    static let sweepDetail =
        "Larger things, 15 cm and up. Move the phone over the surfaces. Uses the depth sensor."
    static let photosDetail =
        "Small parts, finer detail. Circle the object. Uses photographs with depth for size."
    static let surfaceTip =
        "Matt, light-coloured surfaces scan best. Shiny, dark or clear parts may need a matt coating."

    let environment: AppEnvironment
    let photoCapture: PhotoCaptureScreen?
    /// Called after a sweep is saved, with the new scan's identity.
    let onScanSaved: (UUID) -> Void

    @State private var capturing = false
    @State private var savedScan: UUID?

    var body: some View {
        List {
            Section {
                Button {
                    environment.log.info("ui", "Capture method chosen", ["method": CaptureMethod.sweep.rawValue])
                    savedScan = nil
                    capturing = true
                } label: {
                    MethodRow(title: "Sweep", symbol: "move.3d", detail: Self.sweepDetail)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the camera to sweep a subject")

                if let photoCapture {
                    NavigationLink {
                        photoCapture()
                    } label: {
                        photosRow(reason: nil)
                    }
                } else {
                    // A real button, switched off, so the screen reader says "dimmed".
                    Button {
                    } label: {
                        photosRow(reason: Self.photosUnavailableReason)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .accessibilityHint(Self.photosUnavailableReason)
                }
            } header: {
                Text("Capture method")
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                Text(Self.surfaceTip)
                    .font(.footnote)
            } header: {
                Text("Tip")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle("New scan")
        .fullScreenCover(isPresented: $capturing) {
            // Runs after the Capture screen has gone, so the library can safely move
            // on to the new scan.
            if let savedScan {
                onScanSaved(savedScan)
            }
        } content: {
            CaptureView(model: CaptureModel(environment: environment)) { scan in
                savedScan = scan
                capturing = false
            }
        }
        .onAppear {
            environment.log.info("ui", "New scan shown", ["photos": photoCapture == nil ? "not yet" : "available"])
        }
    }

    private func photosRow(reason: String?) -> some View {
        MethodRow(
            title: "Photos", symbol: "camera.on.rectangle",
            detail: Self.photosDetail,
            unavailableReason: reason)
    }
}

/// One method card: name, what it is for, and why it cannot be used yet if so.
private struct MethodRow: View {
    let title: String
    let symbol: String
    let detail: String
    var unavailableReason: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let unavailableReason {
                    Text(unavailableReason)
                        .font(.footnote.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
            if unavailableReason == nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        NewScanView(environment: .preview(), photoCapture: nil) { _ in }
    }
}
