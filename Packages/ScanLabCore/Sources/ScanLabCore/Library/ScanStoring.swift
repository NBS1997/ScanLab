import Foundation

/// Why a library operation failed. Each case says what happened and what to do next,
/// so the screen can show it in place (mockups decision Q3-A).
public enum StoreError: Error, Equatable, Sendable {
    /// No scan has this identity: it may have been deleted already.
    case notFound(UUID)
    /// The phone does not have room for the scan. Nothing was written (NFR-9).
    case noSpace
    /// The new name is empty once spaces are trimmed.
    case emptyName
    /// The new name is longer than `ScanNaming.maximumLength` characters.
    case nameTooLong(maximum: Int)
    /// A file could not be written. Nothing half-written is left behind (NFR-8).
    case writeFailed(String)
    /// A file could not be read.
    case readFailed(String)
    /// A file was read but its contents are damaged.
    case corrupt(String)
}

extension StoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "This scan could not be found. It may have been deleted. Go back to the library and refresh."
        case .noSpace:
            return "There is not enough free space to save the scan, so nothing was saved. "
                + "Free up some space, then try again."
        case .emptyName:
            return "The name cannot be empty. Type a name, then try again."
        case .nameTooLong(let maximum):
            return "The name is too long. Use \(maximum) characters or fewer."
        case .writeFailed(let reason):
            return "The scan could not be saved: \(reason). Nothing was changed. Try again."
        case .readFailed(let reason):
            return "The scan could not be read: \(reason)."
        case .corrupt(let reason):
            return "The scan is damaged: \(reason)."
        }
    }
}

/// How much of the phone's storage a scan uses (NFR-9, FR-6.6).
public struct StorageUse: Equatable, Sendable {
    /// The model, its manifest and its thumbnail.
    public var modelBytes: Int64
    /// The kept raw capture (photographs and camera positions); zero when none is kept.
    public var rawCaptureBytes: Int64

    public init(modelBytes: Int64, rawCaptureBytes: Int64 = 0) {
        self.modelBytes = modelBytes
        self.rawCaptureBytes = rawCaptureBytes
    }

    public static let none = StorageUse(modelBytes: 0)

    /// Everything the scan's folder holds: what deleting the scan frees.
    public var totalBytes: Int64 { modelBytes + rawCaptureBytes }
}

/// The port through which the library reaches storage (ADR-003, ADR-007). The app
/// supplies `FileScanStore`, one folder per scan in Application Support; tests use
/// `MemoryScanStore`.
///
/// The methods are synchronous on purpose. Only `ScanLibrary`, an actor, calls them,
/// so one call finishes completely before the next starts: there is exactly one
/// writer, and two changes can never interleave half-way (services.md).
///
/// The store deals in bytes; turning bytes into scans and meshes is Core's job, so it
/// can be tested without the phone.
public protocol ScanStoring: Sendable {
    /// The identity of every scan folder present, in no particular order. Folders that
    /// are not scans, such as an unfinished write, are left out.
    func scanIDs() throws -> [UUID]

    /// The scan's `manifest.json`. Throws `StoreError.notFound` for an unknown scan.
    func manifestData(for id: UUID) throws -> Data

    /// The scan's model file.
    func meshData(for id: UUID) throws -> Data

    /// The scan's thumbnail in the store's own picture format (PNG for the file
    /// store), or `nil` when there is none.
    func thumbnailData(for id: UUID) -> Data?

    /// Stores a new scan all at once: afterwards the scan is either complete or not
    /// there at all, even if the app is killed part-way (NFR-8).
    func create(_ id: UUID, manifest: Data, mesh: Data, thumbnail: RGBAImage?) throws

    /// Replaces the scan's manifest in one step, for a rename or a changed flag.
    func replaceManifest(_ manifest: Data, for id: UUID) throws

    /// Removes the scan's folder and everything in it.
    func remove(_ id: UUID) throws

    /// How much storage the scan's folder uses.
    func storage(for id: UUID) throws -> StorageUse

    /// The scan's stored accuracy report (unit U10), or `nil` when it has none.
    func reportData(for id: UUID) throws -> Data?

    /// Stores the scan's accuracy report in one step, replacing any earlier one.
    func replaceReport(_ report: Data, for id: UUID) throws
}

/// A store kept in memory, for tests and screen previews. It can be told to fail, so
/// tests can check what happens when storage goes wrong.
public final class MemoryScanStore: ScanStoring, @unchecked Sendable {
    // @unchecked Sendable is safe here because every access to the stored values goes
    // through `lock`.
    private let lock = NSLock()
    private var manifests: [UUID: Data] = [:]
    private var meshes: [UUID: Data] = [:]
    private var thumbnails: [UUID: RGBAImage] = [:]
    private var rawCaptures: [UUID: Int64] = [:]
    private var reports: [UUID: Data] = [:]
    private var failure: StoreError?

    public init() {}

    /// Makes every later write fail with `error`, or succeed again when `nil`.
    public func failWrites(with error: StoreError?) {
        lock.withLock { failure = error }
    }

    /// Puts bytes straight into a manifest, for testing damaged files.
    public func setManifestData(_ data: Data, for id: UUID) {
        lock.withLock { manifests[id] = data }
    }

    /// Pretends the scan has a kept raw capture of this size.
    public func setRawCaptureBytes(_ bytes: Int64, for id: UUID) {
        lock.withLock { rawCaptures[id] = bytes }
    }

    public func scanIDs() throws -> [UUID] {
        lock.withLock { Array(manifests.keys) }
    }

    public func manifestData(for id: UUID) throws -> Data {
        try lock.withLock {
            guard let data = manifests[id] else { throw StoreError.notFound(id) }
            return data
        }
    }

    public func meshData(for id: UUID) throws -> Data {
        try lock.withLock {
            guard let data = meshes[id] else { throw StoreError.notFound(id) }
            return data
        }
    }

    public func thumbnailData(for id: UUID) -> Data? {
        lock.withLock { thumbnails[id].map { Data($0.bytes) } }
    }

    public func create(_ id: UUID, manifest: Data, mesh: Data, thumbnail: RGBAImage?) throws {
        try lock.withLock {
            if let failure { throw failure }
            manifests[id] = manifest
            meshes[id] = mesh
            thumbnails[id] = thumbnail
        }
    }

    public func replaceManifest(_ manifest: Data, for id: UUID) throws {
        try lock.withLock {
            if let failure { throw failure }
            guard manifests[id] != nil else { throw StoreError.notFound(id) }
            manifests[id] = manifest
        }
    }

    public func remove(_ id: UUID) throws {
        try lock.withLock {
            if let failure { throw failure }
            guard manifests.removeValue(forKey: id) != nil else { throw StoreError.notFound(id) }
            meshes[id] = nil
            thumbnails[id] = nil
            rawCaptures[id] = nil
            reports[id] = nil
        }
    }

    public func storage(for id: UUID) throws -> StorageUse {
        try lock.withLock {
            guard let manifest = manifests[id] else { throw StoreError.notFound(id) }
            let model = manifest.count + (meshes[id]?.count ?? 0) + (thumbnails[id]?.bytes.count ?? 0)
            return StorageUse(modelBytes: Int64(model), rawCaptureBytes: rawCaptures[id] ?? 0)
        }
    }

    public func reportData(for id: UUID) throws -> Data? {
        try lock.withLock {
            guard manifests[id] != nil else { throw StoreError.notFound(id) }
            return reports[id]
        }
    }

    public func replaceReport(_ report: Data, for id: UUID) throws {
        try lock.withLock {
            if let failure { throw failure }
            guard manifests[id] != nil else { throw StoreError.notFound(id) }
            reports[id] = report
        }
    }
}
