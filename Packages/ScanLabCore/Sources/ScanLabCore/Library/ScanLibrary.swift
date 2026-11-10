import Foundation

/// What a read of the whole library returns: the scans that could be read, newest
/// first, and how many scan folders could not (business rule SL-8).
public struct ScanListing: Equatable, Sendable {
    public var scans: [Scan]
    /// Scan folders whose details were missing or damaged. They are left untouched on
    /// the phone, so nothing is lost, but are not shown.
    public var unreadable: Int

    public init(scans: [Scan] = [], unreadable: Int = 0) {
        self.scans = scans
        self.unreadable = unreadable
    }
}

/// The one owner of saved scans (LibraryService in services.md). Every read and write
/// of scan data goes through it.
///
/// It is an **actor**: Swift runs its methods one at a time, so there is only ever one
/// change in progress. Combined with the store's synchronous methods, a rename can
/// never interleave with a delete, and so on.
///
/// Every change, and every failure, is written to the diagnostics log under the
/// category `library` (project rule; ADR-011).
public actor ScanLibrary {
    /// Room kept free beyond the scan itself: the temporary copy of the manifest, the
    /// thumbnail, and some spare so the phone is not filled to the last byte.
    public static let spareBytes: Int64 = 2_000_000

    private let store: any ScanStoring
    private let log: any Logging
    private let availableBytes: @Sendable () -> Int64?
    private let now: @Sendable () -> Date
    private let timeZone: TimeZone
    private let thumbnails: ThumbnailRenderer

    /// - Parameters:
    ///   - availableBytes: free space on the phone's storage, or `nil` when it cannot
    ///     be read (the save is then attempted, and a full storage is still reported
    ///     by the store as `.noSpace`).
    ///   - now: the clock, replaceable in tests.
    public init(
        store: any ScanStoring,
        log: any Logging,
        availableBytes: @escaping @Sendable () -> Int64? = { nil },
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: TimeZone = .current
    ) {
        self.store = store
        self.log = log
        self.availableBytes = availableBytes
        self.now = now
        self.timeZone = timeZone
        self.thumbnails = ThumbnailRenderer()
    }

    /// Every readable scan, newest first. A damaged scan is skipped and counted, never
    /// allowed to stop the rest of the library showing.
    public func all() throws -> ScanListing {
        let ids: [UUID]
        do {
            ids = try store.scanIDs()
        } catch {
            log.error("library", "Library could not be read", ["reason": reason(error)])
            throw error
        }
        var listing = ScanListing()
        for id in ids {
            do {
                listing.scans.append(try readManifest(id))
            } catch {
                listing.unreadable += 1
                log.warning("library", "Scan skipped", ["scan": short(id), "reason": reason(error)])
            }
        }
        // Newest first; the identity breaks ties so the order never jumps about.
        listing.scans.sort {
            $0.createdAt != $1.createdAt ? $0.createdAt > $1.createdAt : $0.id.uuidString < $1.id.uuidString
        }
        return listing
    }

    /// One scan's details.
    public func scan(_ id: UUID) throws -> Scan {
        try readManifest(id)
    }

    /// One scan's model, for Scan detail and Export.
    public func mesh(for id: UUID) throws -> Mesh {
        do {
            return try MeshBinary.decode(try store.meshData(for: id))
        } catch {
            log.error("library", "Model could not be read", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// The scan's thumbnail in the store's picture format, or `nil` when there is none.
    public func thumbnail(for id: UUID) -> Data? {
        store.thumbnailData(for: id)
    }

    /// Saves a finished model as a new scan (called by capture in units U07 and U08,
    /// and by Diagnostics for the sample).
    ///
    /// The free space is checked first; when there is not enough, nothing is written
    /// and `StoreError.noSpace` is thrown (NFR-9).
    /// - Parameters:
    ///   - detail: the detail level the model was built at, if it matters (FR-4.2).
    ///   - name: the scan's name; when `nil`, the method and date, such as
    ///     "Sweep 11 Nov 14:05".
    @discardableResult
    public func add(mesh: Mesh, method: CaptureMethod, detail: String? = nil, name: String? = nil) throws -> Scan {
        let started = Date()
        // Whole seconds only, so the date reads back exactly from the manifest.
        let created = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        do {
            var scanName = ScanNaming.defaultName(method: method, date: created, timeZone: timeZone)
            if let name {
                scanName = try ScanNaming.validated(name)
            }
            let scan = Scan(
                name: scanName, method: method, createdAt: created, detailLevel: detail,
                faceCount: mesh.faceCount, size: mesh.boundingBox?.size)
            let meshData = try MeshBinary.encode(mesh)
            let manifest = try ManifestCodec.encode(scan)
            try checkSpace(for: Int64(meshData.count + manifest.count))
            let picture = thumbnails.render(mesh)
            try store.create(scan.id, manifest: manifest, mesh: meshData, thumbnail: picture)
            log.info(
                "library", "Scan added",
                [
                    "scan": short(scan.id), "method": method.rawValue, "faces": String(mesh.faceCount),
                    "bytes": String(meshData.count), "ms": milliseconds(since: started),
                ])
            return scan
        } catch {
            log.error("library", "Scan not added", ["method": method.rawValue, "reason": reason(error)])
            throw error
        }
    }

    /// Gives a scan a new name: trimmed, not empty, at most 80 characters (SL-3).
    @discardableResult
    public func rename(_ id: UUID, to newName: String) throws -> Scan {
        do {
            let name = try ScanNaming.validated(newName)
            var scan = try readManifest(id)
            scan.name = name
            try store.replaceManifest(try ManifestCodec.encode(scan), for: id)
            log.info("library", "Scan renamed", ["scan": short(id), "characters": String(name.count)])
            return scan
        } catch {
            log.error("library", "Scan not renamed", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// Deletes a scan and everything stored with it. Returns the storage freed, which
    /// the screen has already shown in its confirmation (SL-6).
    @discardableResult
    public func delete(_ id: UUID) throws -> StorageUse {
        do {
            let freed = (try? store.storage(for: id)) ?? .none
            try store.remove(id)
            log.info("library", "Scan deleted", ["scan": short(id), "bytes": String(freed.totalBytes)])
            return freed
        } catch {
            log.error("library", "Scan not deleted", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// How much storage a scan uses, split into model and raw capture (NFR-9).
    public func storage(for id: UUID) throws -> StorageUse {
        do {
            return try store.storage(for: id)
        } catch {
            log.warning("library", "Scan size not read", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// Marks a scan as being of the printed reference object, or not (unit U10).
    @discardableResult
    public func setReference(_ id: UUID, _ isReference: Bool) throws -> Scan {
        do {
            var scan = try readManifest(id)
            scan.isReference = isReference
            try store.replaceManifest(try ManifestCodec.encode(scan), for: id)
            log.info("library", "Reference mark changed", ["scan": short(id), "reference": String(isReference)])
            return scan
        } catch {
            log.error("library", "Reference mark not changed", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    // MARK: Raw capture (unit U08)

    /// Keeps a photo scan's raw capture with it (FR-6.6): the folder is moved into the
    /// scan, so Delete frees it and the scan's storage figure includes it, and its size
    /// is recorded in the manifest. Moving within the phone's storage needs no extra
    /// space.
    @discardableResult
    public func keepRawCapture(_ id: UUID, from folder: URL) throws -> Scan {
        do {
            var scan = try readManifest(id)
            try store.attachRawCapture(from: folder, to: id)
            let bytes = (try? store.storage(for: id))?.rawCaptureBytes ?? 0
            scan.rawCaptureBytes = bytes
            try store.replaceManifest(try ManifestCodec.encode(scan), for: id)
            log.info("library", "Raw capture kept", ["scan": short(id), "bytes": String(bytes)])
            return scan
        } catch {
            log.error("library", "Raw capture not kept", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// Removes a scan's kept raw capture, freeing its storage. A scan without one is
    /// left as it is.
    @discardableResult
    public func discardRawCapture(_ id: UUID) throws -> Scan {
        do {
            var scan = try readManifest(id)
            let freed = (try? store.storage(for: id))?.rawCaptureBytes ?? 0
            try store.removeRawCapture(for: id)
            if scan.rawCaptureBytes != nil {
                scan.rawCaptureBytes = nil
                try store.replaceManifest(try ManifestCodec.encode(scan), for: id)
            }
            log.info("library", "Raw capture discarded", ["scan": short(id), "bytes": String(freed)])
            return scan
        } catch {
            log.error("library", "Raw capture not discarded", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// Stores an encoded accuracy report with the scan, replacing any earlier one, and
    /// sets `hasAccuracyReport` (unit U10). The report is written before the manifest,
    /// so the flag is never set for a report that is not there.
    @discardableResult
    public func attachReport(_ report: Data, to id: UUID) throws -> Scan {
        do {
            var scan = try readManifest(id)
            try checkSpace(for: Int64(report.count))
            try store.replaceReport(report, for: id)
            if !scan.hasAccuracyReport {
                scan.hasAccuracyReport = true
                try store.replaceManifest(try ManifestCodec.encode(scan), for: id)
            }
            log.info("library", "Accuracy report saved", ["scan": short(id), "bytes": String(report.count)])
            return scan
        } catch {
            log.error("library", "Accuracy report not saved", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    /// Where the scan's kept raw capture is, for export (FR-7.5), or `nil` when none.
    public func rawCaptureFolder(for id: UUID) -> URL? {
        store.rawCaptureFolder(for: id)
    }

    /// The scan's encoded accuracy report, or `nil` when it has none.
    public func reportData(for id: UUID) throws -> Data? {
        do {
            return try store.reportData(for: id)
        } catch {
            log.error("library", "Accuracy report not read", ["scan": short(id), "reason": reason(error)])
            throw error
        }
    }

    private func readManifest(_ id: UUID) throws -> Scan {
        let scan = try ManifestCodec.decode(try store.manifestData(for: id))
        // A manifest copied into the wrong folder would otherwise make two scans
        // share an identity.
        guard scan.id == id else { throw StoreError.corrupt("the scan details belong to another scan") }
        return scan
    }

    private func checkSpace(for bytes: Int64) throws {
        guard let available = availableBytes() else { return }
        if available < bytes + Self.spareBytes {
            log.warning("library", "Not enough space", ["needed": String(bytes), "available": String(available)])
            throw StoreError.noSpace
        }
    }

    /// The first eight characters of the identity: enough to tell scans apart in the
    /// log without filling it.
    private func short(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private func reason(_ error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    private func milliseconds(since start: Date) -> String {
        String(Int(Date().timeIntervalSince(start) * 1000))
    }
}
