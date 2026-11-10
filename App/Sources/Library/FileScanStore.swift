import Foundation
import ImageIO
import ScanLabCore
import UniformTypeIdentifiers

/// The real scan storage (ADR-007): one folder per scan inside the app's own
/// Application Support area, which survives app updates and is included in the
/// phone's backups.
///
/// ```
/// Application Support/Scans/
///     3F2C…-…/              one scan, named by its identity
///         manifest.json     name, method, date, sizes and flags
///         mesh.slmesh       the model (Core's MeshBinary layout)
///         thumbnail.png     the 160 × 160 list picture
///         RawCapture/       photographs and camera positions, when kept (unit U08)
///     .incoming-…/          a scan being written; never listed
/// ```
///
/// **How a crash can never leave a half-written scan (NFR-8):** a new scan's files are
/// written into a hidden `.incoming-…` folder first. Only when every file is complete
/// is that folder renamed to the scan's identity. A rename on the same storage happens
/// in one step: the scan is either fully there or not there at all. Leftover
/// `.incoming-…` folders from a crash are removed the next time the library is read.
/// A manifest change (rename, flag) replaces the file in one step the same way.
struct FileScanStore: ScanStoring {
    static let manifestName = "manifest.json"
    static let meshName = "mesh.slmesh"
    static let thumbnailName = "thumbnail.png"
    static let rawCaptureName = "RawCapture"
    private static let incomingPrefix = ".incoming-"

    /// The `Scans` folder.
    let root: URL
    let log: any Logging

    /// The standard location: Application Support/Scans inside the app's own storage.
    static func standardDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Scans", directoryHint: .isDirectory)
    }

    func folder(for id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    /// Free space for important data on the phone's storage, or `nil` when it cannot
    /// be read. "Important usage" counts space the system would free by clearing
    /// caches, which is what the phone offers to an app saving the owner's own work.
    func availableCapacity() -> Int64? {
        do {
            try ensureRoot()
            let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            log.warning("library", "Free space not read", ["reason": error.localizedDescription])
            return nil
        }
    }

    func scanIDs() throws -> [UUID] {
        let manager = FileManager.default
        let names: [String]
        do {
            try ensureRoot()
            names = try manager.contentsOfDirectory(atPath: root.path())
        } catch {
            throw StoreError.readFailed(error.localizedDescription)
        }
        var ids: [UUID] = []
        for name in names {
            if name.hasPrefix(Self.incomingPrefix) {
                removeLeftover(named: name)
            } else if let id = UUID(uuidString: name) {
                ids.append(id)
            }
        }
        return ids
    }

    func manifestData(for id: UUID) throws -> Data {
        try read(Self.manifestName, of: id)
    }

    func meshData(for id: UUID) throws -> Data {
        try read(Self.meshName, of: id)
    }

    func thumbnailData(for id: UUID) -> Data? {
        try? Data(contentsOf: folder(for: id).appending(path: Self.thumbnailName))
    }

    func create(_ id: UUID, manifest: Data, mesh: Data, thumbnail: RGBAImage?) throws {
        let manager = FileManager.default
        let incoming = root.appending(path: Self.incomingPrefix + id.uuidString, directoryHint: .isDirectory)
        do {
            try ensureRoot()
            try manager.createDirectory(at: incoming, withIntermediateDirectories: true)
            try mesh.write(to: incoming.appending(path: Self.meshName))
            if let thumbnail {
                if let png = Self.pngData(thumbnail) {
                    try png.write(to: incoming.appending(path: Self.thumbnailName))
                } else {
                    log.warning("library", "Thumbnail not encoded", ["scan": String(id.uuidString.prefix(8))])
                }
            }
            // The manifest goes last: a folder with a manifest is a finished scan.
            try manifest.write(to: incoming.appending(path: Self.manifestName))
            try manager.moveItem(at: incoming, to: folder(for: id))
        } catch {
            try? manager.removeItem(at: incoming)
            throw Self.classify(error)
        }
    }

    func replaceManifest(_ manifest: Data, for id: UUID) throws {
        let url = try existingFolder(id).appending(path: Self.manifestName)
        do {
            // `.atomic` writes a temporary file beside it and swaps it in.
            try manifest.write(to: url, options: .atomic)
        } catch {
            throw Self.classify(error)
        }
    }

    func remove(_ id: UUID) throws {
        let url = try existingFolder(id)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw Self.classify(error)
        }
    }

    func storage(for id: UUID) throws -> StorageUse {
        let url = try existingFolder(id)
        let raw = url.appending(path: Self.rawCaptureName, directoryHint: .isDirectory)
        let total = Self.bytes(in: url)
        let rawBytes = Self.bytes(in: raw)
        return StorageUse(modelBytes: max(total - rawBytes, 0), rawCaptureBytes: rawBytes)
    }

    // MARK: - Helpers

    private func ensureRoot() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func existingFolder(_ id: UUID) throws -> URL {
        let url = folder(for: id)
        guard FileManager.default.fileExists(atPath: url.path()) else { throw StoreError.notFound(id) }
        return url
    }

    private func read(_ name: String, of id: UUID) throws -> Data {
        let url = try existingFolder(id).appending(path: name)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw StoreError.readFailed(error.localizedDescription)
        }
    }

    private func removeLeftover(named name: String) {
        do {
            try FileManager.default.removeItem(at: root.appending(path: name))
            log.warning("library", "Unfinished scan removed", ["folder": name])
        } catch {
            log.error("library", "Unfinished scan not removed", ["reason": error.localizedDescription])
        }
    }

    /// The space the folder's files take on the phone, counting every file inside it
    /// and inside its sub-folders. Zero for a folder that does not exist.
    static func bytes(in folder: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard
            let files = FileManager.default.enumerator(
                at: folder, includingPropertiesForKeys: keys, options: [], errorHandler: nil)
        else { return 0 }
        var total: Int64 = 0
        for case let file as URL in files {
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    /// Turns a file-system error into a `StoreError`, recognising "storage full".
    static func classify(_ error: any Error) -> StoreError {
        if let storeError = error as? StoreError { return storeError }
        switch MeshFiles.classify(error) {
        case .noSpace: return .noSpace
        default: return .writeFailed(error.localizedDescription)
        }
    }

    /// The picture as a PNG file, or `nil` if it could not be encoded (the scan is
    /// still saved; the list then shows a plain icon).
    static func pngData(_ image: RGBAImage) -> Data? {
        guard let picture = image.makeCGImage() else { return nil }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data as CFMutableData, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, picture, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
