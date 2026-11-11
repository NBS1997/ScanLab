import Foundation
import ScanLabCore

/// One detail level's state on the Export screen.
enum LevelState: Sendable {
    case working
    case ready(Mesh)
    case failed(String)
}

/// The model at every detail level, worked out before the owner chooses.
struct PreparedExport: Sendable {
    let source: Mesh
    let levels: [ExportDetail: LevelState]
}

/// A written file waiting for the owner to choose where it goes.
struct PendingExport: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let faces: Int
    let bytes: Int
}

/// How the save chooser finished.
enum PickerOutcome: Sendable {
    case saved(URL)
    case cancelled
}

/// The export steps (components.md, ExportService): simplify to each detail level,
/// write the chosen one to a temporary file in millimetres, then hand that file to
/// the phone's save chooser (FR-7.4). Every step and every failure is logged, so an
/// export that went wrong can be understood from Diagnostics alone.
struct ExportService: Sendable {
    let log: any Logging
    /// Where files wait for the save chooser. Emptied after each export.
    var folder: URL = URL.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)

    /// Builds the model and simplifies it to every level, away from the main thread
    /// so the screen stays responsive.
    func prepareLevels(name: String, loadMesh: @escaping @Sendable () -> Mesh) async -> PreparedExport {
        let started = Date()
        let prepared = await Task.detached(priority: .userInitiated) {
            Self.simplifyAll(loadMesh())
        }.value
        let elapsed = Self.milliseconds(since: started)
        var details = ["model": name, "faces": String(prepared.source.faceCount), "ms": elapsed]
        for (detail, state) in prepared.levels {
            switch state {
            case .ready(let mesh):
                details[detail.rawValue] = String(mesh.faceCount)
            case .failed(let reason):
                log.error("export", "Simplification failed", ["detail": detail.rawValue, "reason": reason])
            case .working:
                break
            }
        }
        log.info("export", "Export levels ready", details)
        return prepared
    }

    /// Writes the mesh to a temporary file, refusing early if the phone lacks space
    /// so no partial file is left behind (NFR-9).
    func writeTemporaryFile(
        _ mesh: Mesh, name: String, detail: ExportDetail, format: MeshFormat
    ) async throws -> PendingExport {
        let fileName = ExportNaming.fileName(for: name, detail: detail, format: format)
        let folder = folder
        let started = Date()
        do {
            let pending = try await Task.detached(priority: .userInitiated) {
                try Self.write(mesh, format: format, fileName: fileName, in: folder)
            }.value
            log.info(
                "export", "Export file written",
                [
                    "detail": detail.rawValue, "format": format.rawValue, "faces": String(pending.faces),
                    "bytes": String(pending.bytes), "ms": Self.milliseconds(since: started),
                ])
            return pending
        } catch {
            let failure = MeshFiles.classify(error)
            let reason = failure.errorDescription ?? String(describing: failure)
            let context = ["detail": detail.rawValue, "format": format.rawValue, "reason": reason]
            log.error("export", "Export file failed", context)
            throw failure
        }
    }

    /// Records how the save chooser finished and removes the temporary file.
    func finish(_ pending: PendingExport, outcome: PickerOutcome) {
        switch outcome {
        case .saved(let destination):
            let place = destination.deletingLastPathComponent().lastPathComponent
            log.info("export", "Export saved", ["file": destination.lastPathComponent, "folder": place])
        case .cancelled:
            log.info("export", "Export cancelled", ["file": pending.url.lastPathComponent])
        }
        do {
            try FileManager.default.removeItem(at: pending.url)
        } catch {
            log.warning("export", "Temporary export file not removed", ["reason": error.localizedDescription])
        }
    }

    private static func simplifyAll(_ mesh: Mesh) -> PreparedExport {
        var levels: [ExportDetail: LevelState] = [:]
        for detail in ExportDetail.allCases {
            do {
                levels[detail] = .ready(try detail.prepare(mesh))
            } catch {
                levels[detail] = .failed(error.localizedDescription)
            }
        }
        return PreparedExport(source: mesh, levels: levels)
    }

    private static func write(
        _ mesh: Mesh, format: MeshFormat, fileName: String, in folder: URL
    ) throws -> PendingExport {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw MeshFiles.classify(error)
        }
        let url = folder.appending(path: fileName)
        if manager.fileExists(atPath: url.fileSystemPath) {
            try manager.removeItem(at: url)
        }
        let data = try MeshFiles.data(for: mesh, as: format)
        // When the free space cannot be read, the write itself still reports a full
        // storage as `.noSpace`; the early check only makes the common case cleaner.
        let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        try MeshFiles.write(data, to: url, availableCapacity: values?.volumeAvailableCapacityForImportantUsage)
        return PendingExport(url: url, faces: mesh.faceCount, bytes: data.count)
    }

    private static func milliseconds(since start: Date) -> String {
        String(Int(Date().timeIntervalSince(start) * 1000))
    }
}
