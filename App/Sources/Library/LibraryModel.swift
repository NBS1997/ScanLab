import Foundation
import Observation
import ScanLabCore
import UIKit

/// One row of the library list: the scan, its size on the phone and its picture.
struct LibraryRow: Identifiable {
    var scan: Scan
    /// `nil` while unknown, or when the size could not be read.
    var storage: StorageUse?
    var thumbnail: UIImage?

    var id: UUID { scan.id }
}

/// What the Library screen shows (mockups screen 1), kept apart from the view.
@MainActor
@Observable
final class LibraryModel {
    private(set) var rows: [LibraryRow] = []
    /// Scan folders that could not be read and are not shown (business rule SL-8).
    private(set) var unreadable = 0
    private(set) var hasLoaded = false
    /// Shown in place of the list when the library itself cannot be read.
    private(set) var loadError: String?
    /// Shown above the list when a rename or delete failed, until the next attempt.
    private(set) var actionError: String?

    let environment: AppEnvironment
    private var library: ScanLibrary { environment.library }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// Reads every scan, newest first, with sizes and thumbnails.
    func reload() async {
        do {
            let listing = try await library.all()
            var loaded: [LibraryRow] = []
            for scan in listing.scans {
                let storage = try? await library.storage(for: scan.id)
                let picture = await library.thumbnail(for: scan.id).flatMap { UIImage(data: $0) }
                loaded.append(LibraryRow(scan: scan, storage: storage, thumbnail: picture))
            }
            rows = loaded
            unreadable = listing.unreadable
            loadError = nil
        } catch {
            // Already logged by the library.
            loadError = error.localizedDescription
        }
        if !hasLoaded {
            hasLoaded = true
            let details = ["scans": String(rows.count), "unreadable": String(unreadable)]
            environment.log.info("ui", "Library shown", details)
        }
    }

    /// Renames a scan. Returns whether it worked; on failure the reason is shown.
    @discardableResult
    func rename(_ id: UUID, to name: String) async -> Bool {
        actionError = nil
        do {
            let scan = try await library.rename(id, to: name)
            if let index = rows.firstIndex(where: { $0.id == id }) {
                rows[index].scan = scan
            }
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    /// Deletes a scan after the owner has confirmed.
    func delete(_ id: UUID) async {
        actionError = nil
        do {
            try await library.delete(id)
            rows.removeAll { $0.id == id }
        } catch {
            actionError = error.localizedDescription
        }
    }
}

/// Words shared by the Library and Scan detail screens.
enum ScanText {
    /// The row's second line: "Sweep · 11 Nov · 4.8 MB".
    static func summary(_ scan: Scan, storage: StorageUse?) -> String {
        var parts = [scan.method.displayName, ScanNaming.shortDate(scan.createdAt)]
        if let storage {
            parts.append(Units.storage(storage.totalBytes))
        }
        return parts.joined(separator: " · ")
    }

    /// "Photos · reduced detail", or just "Sweep" when no detail level applies.
    static func method(_ scan: Scan) -> String {
        guard let detail = scan.detailLevel, !detail.isEmpty else { return scan.method.displayName }
        return "\(scan.method.displayName) · \(detail) detail"
    }

    static func size(_ scan: Scan) -> String {
        scan.size.map(Units.formatDimensions) ?? "No faces"
    }

    static func rawCapture(_ scan: Scan, storage: StorageUse?) -> String {
        let bytes = storage?.rawCaptureBytes ?? scan.rawCaptureBytes ?? 0
        return bytes > 0 ? "Kept · \(Units.storage(bytes))" : "None"
    }

    /// The delete confirmation's title: "Delete “Kayak hull”?".
    static func deleteTitle(_ scan: Scan) -> String {
        "Delete \u{201C}\(scan.name)\u{201D}?"
    }

    /// The delete confirmation's message, naming what is lost and the storage freed
    /// (interaction-spec.md, Destructive Actions).
    static func deleteMessage(_ scan: Scan, storage: StorageUse?) -> String {
        let lost = (storage?.rawCaptureBytes ?? 0) > 0 ? "The model and its raw capture" : "The model"
        guard let storage else { return "\(lost) will be removed from this phone. This cannot be undone." }
        let freed = Units.storage(storage.totalBytes)
        return "\(lost) will be removed from this phone, freeing \(freed). This cannot be undone."
    }
}
