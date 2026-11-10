import ScanLabCore
import SwiftUI

/// The opening screen (mockups screen 1). In the walking skeleton it only shows the
/// empty state; scans arrive with Bolts 5–7.
struct LibraryView: View {
    let environment: AppEnvironment

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No scans yet", systemImage: "cube.transparent")
            } description: {
                Text("Scanning arrives in a later build. Diagnostics shows what this build has done.")
            }
            .navigationTitle("Scans")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Diagnostics") {
                        DiagnosticsView(model: DiagnosticsModel(environment: environment))
                    }
                }
            }
        }
        .onAppear {
            environment.log.info("ui", "Library shown", ["scans": "0"])
        }
    }
}

#Preview {
    LibraryView(environment: .preview())
}
