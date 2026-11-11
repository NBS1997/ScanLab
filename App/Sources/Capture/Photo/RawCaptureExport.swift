import Foundation
import ScanLabCore
import SwiftUI

/// Exports a kept raw capture (FR-7.5, US-11): the photographs, camera positions and
/// README, packed into one zip file and handed to the phone's save chooser.
///
/// **How the zip is made without third-party code:** asking the system's file
/// coordinator to read a folder "for uploading" (`NSFileCoordinator`'s
/// `.forUploading` option) makes it pack the folder into a temporary zip file first,
/// the same way the Files app shares a folder. That zip only exists while the
/// coordinator's block runs, so it is moved (or copied) out to ScanLab's own temporary
/// folder before the block ends.
struct RawCaptureExporter: Sendable {
    let log: any Logging
    /// Where zips wait for the save chooser. Emptied after each export.
    var folder: URL = URL.temporaryDirectory.appending(path: "RawExport", directoryHint: .isDirectory)

    /// Packs the raw capture into `<scan name> raw capture.zip`. Fails with
    /// `PhotoCaptureError.noSpace` before starting when the phone cannot hold a copy.
    func zip(_ source: URL, scanName: String, rawBytes: Int64) async throws -> PendingExport {
        let started = Date()
        let folder = folder
        let name = RawCaptureFiles.exportName(for: scanName)
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try Self.pack(source, into: folder, named: name, rawBytes: rawBytes)
            }.value
            let bytes = RawCaptureFiles.bytes(in: url)
            log.info(
                "photo", "Raw capture zip written",
                ["bytes": String(bytes), "ms": String(Int(Date().timeIntervalSince(started) * 1000))])
            return PendingExport(url: url, faces: 0, bytes: Int(bytes))
        } catch {
            let failure = PhotoCaptureError.from(error)
            log.error("photo", "Raw capture zip failed", ["reason": failure.errorDescription ?? failure.logName])
            throw failure
        }
    }

    /// Records how the save chooser finished and removes the temporary zip.
    func finish(_ pending: PendingExport, outcome: PickerOutcome) {
        switch outcome {
        case .saved(let destination):
            let place = destination.deletingLastPathComponent().lastPathComponent
            log.info("photo", "Raw capture exported", ["file": destination.lastPathComponent, "folder": place])
        case .cancelled:
            log.info("photo", "Raw capture export cancelled")
        }
        do {
            try FileManager.default.removeItem(at: pending.url)
        } catch {
            log.warning("photo", "Temporary raw capture zip not removed", ["reason": error.localizedDescription])
        }
    }

    private static func pack(_ source: URL, into folder: URL, named name: String, rawBytes: Int64) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        // The system's zip and ScanLab's copy can both exist for a moment, so room for
        // two copies plus some spare is needed. Photos barely compress.
        let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values?.volumeAvailableCapacityForImportantUsage ?? .max
        if available < rawBytes * 2 + ScanLibrary.spareBytes {
            throw PhotoCaptureError.noSpace
        }
        let destination = folder.appending(path: name)
        if manager.fileExists(atPath: destination.fileSystemPath) {
            try manager.removeItem(at: destination)
        }
        var coordinationError: NSError?
        var copyError: (any Error)?
        let coordinator = NSFileCoordinator()
        let options: NSFileCoordinator.ReadingOptions = [.forUploading]
        coordinator.coordinate(readingItemAt: source, options: options, error: &coordinationError) { zipped in
            // `zipped` is the system's temporary zip; it is deleted after this block.
            do {
                try manager.moveItem(at: zipped, to: destination)
            } catch {
                do {
                    try manager.copyItem(at: zipped, to: destination)
                } catch {
                    copyError = error
                }
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        return destination
    }
}

/// The "Export raw capture…" row on Scan detail, shown when the scan has a kept raw
/// capture. Packs it, then opens the save chooser; failures are shown in place.
struct RawCaptureExportRow: View {
    let environment: AppEnvironment
    let scanID: UUID
    let scanName: String
    let rawBytes: Int64
    @State private var pending: PendingExport?
    @State private var working = false
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await export() }
            } label: {
                if working {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Packing raw capture…")
                    }
                } else {
                    Label("Export raw capture…", systemImage: "archivebox")
                }
            }
            .disabled(working)
            .accessibilityHint("Saves the photos and camera positions as a zip file, \(Units.storage(rawBytes))")
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
        }
        .sheet(item: $pending) { file in
            DocumentExportPicker(url: file.url) { outcome in
                exporter.finish(file, outcome: outcome)
                if case .saved(let url) = outcome {
                    failed = false
                    message = "Saved \(url.lastPathComponent)."
                }
                pending = nil
            }
            .ignoresSafeArea()
        }
    }

    private var exporter: RawCaptureExporter { RawCaptureExporter(log: environment.log) }

    private func export() async {
        working = true
        message = nil
        defer { working = false }
        guard let source = await environment.library.rawCaptureFolder(for: scanID) else {
            failed = true
            message = "The raw capture could not be found on this phone."
            environment.log.error("photo", "Raw capture missing", ["scan": String(scanID.uuidString.prefix(8))])
            return
        }
        do {
            pending = try await exporter.zip(source, scanName: scanName, rawBytes: rawBytes)
        } catch {
            failed = true
            message = error.localizedDescription
        }
    }
}
