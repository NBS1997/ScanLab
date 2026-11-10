import Foundation
import ScanLabCore

/// Where the owner's caliper values are kept on the phone (FR-8.6):
/// `Application Support/Reference/caliper-values.json`, which survives app updates and
/// is included in the phone's backups. One file for the one printed object.
struct CaliperStore: Sendable {
    let url: URL

    static func standardURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "Reference", directoryHint: .isDirectory)
            .appending(path: "caliper-values.json")
    }

    /// The saved values, or an empty sheet when none have been saved yet.
    func load() throws -> CaliperSheet {
        guard FileManager.default.fileExists(atPath: url.path()) else { return CaliperSheet() }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw StoreError.readFailed(error.localizedDescription)
        }
        return try CaliperSheet.decode(data)
    }

    /// Saves the values in one step: the file is either the old one or the new one,
    /// never half written.
    func save(_ sheet: CaliperSheet) throws {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try sheet.encoded().write(to: url, options: .atomic)
        } catch {
            throw FileScanStore.classify(error)
        }
    }
}
