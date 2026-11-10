import Foundation

/// A capture folder left behind with photographs in it, for example because the app was
/// closed while a model was building. It can be built without capturing again (FR-4.3).
public struct UnfinishedCapture: Equatable, Sendable, Identifiable {
    public var folders: RawCaptureFolders
    public var images: Int
    public var bytes: Int64
    /// When the folder last changed.
    public var modified: Date

    public init(folders: RawCaptureFolders, images: Int, bytes: Int64, modified: Date) {
        self.folders = folders
        self.images = images
        self.bytes = bytes
        self.modified = modified
    }

    public var id: String { folders.id }
}

/// File handling for raw captures: sizes, tidying before keeping, finding unfinished
/// captures and removing them (business rules PC-5 to PC-8). Uses only the file system,
/// so it is tested in the build with temporary folders.
public enum RawCaptureFiles {
    /// File types the platform writes photographs as. HEIC is what Object Capture uses.
    public static let imageExtensions: Set<String> = ["heic", "heif", "jpg", "jpeg", "png"]

    /// The bytes a folder's files take, counting everything in its sub-folders. Zero
    /// for a folder that does not exist. This is the figure shown in the keep-or-discard
    /// question and stored in the scan's manifest.
    public static func bytes(in folder: URL) -> Int64 {
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

    /// How many photographs are in the capture's `Images` folder (including any in
    /// sub-folders, which the platform uses for extra scan passes).
    public static func imageCount(in folders: RawCaptureFolders) -> Int {
        let manager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        let enumerator = manager.enumerator(at: folders.images, includingPropertiesForKeys: nil, options: options)
        guard let files = enumerator else { return 0 }
        var count = 0
        for case let file as URL in files where imageExtensions.contains(file.pathExtension.lowercased()) {
            count += 1
        }
        return count
    }

    /// Readies a capture folder to be kept with its scan: removes the platform's
    /// working data and the built model (the model is already in the scan), and
    /// writes a README explaining what is left. Returns the bytes that remain.
    ///
    /// Only the photographs, the camera positions and the README stay (PC-7): they are
    /// what a rebuild on a computer needs (FR-7.5), and the working data can be larger
    /// than the photographs.
    @discardableResult
    public static func prepareForKeeping(_ folders: RawCaptureFolders, detail: PhotoDetailLevel) throws -> Int64 {
        let manager = FileManager.default
        do {
            let names = try manager.contentsOfDirectory(atPath: folders.root.path())
            for name in names where !RawCaptureFolders.keptNames.contains(name) {
                try manager.removeItem(at: folders.root.appending(path: name))
            }
            let hasPositions = manager.fileExists(atPath: folders.cameraPositions.path())
            let text = readMe(images: imageCount(in: folders), hasPositions: hasPositions, detail: detail)
            try Data(text.utf8).write(to: folders.readMe, options: .atomic)
        } catch {
            throw PhotoCaptureError.from(error)
        }
        return bytes(in: folders.root)
    }

    /// The README written into a kept raw capture, so the folder makes sense when it is
    /// opened on a computer months later.
    public static func readMe(images: Int, hasPositions: Bool, detail: PhotoDetailLevel) -> String {
        var lines = [
            "ScanLab raw capture",
            "",
            "Images/ holds \(PhotoBuildText.photos(images)) taken by Apple's Object Capture.",
            "Each HEIC file also carries the depth picture and gravity direction for that shot.",
        ]
        if hasPositions {
            lines.append("camera-positions.csv gives where the camera was for each photo, in metres (y points up).")
        } else {
            lines.append("No camera positions were produced for this capture.")
        }
        lines.append("The phone built its model at \(detail.manifestValue) detail.")
        lines.append("A computer with photogrammetry software can rebuild the model from Images/.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Capture folders inside `parent` that still hold photographs, newest first.
    /// Folders with no photographs (a capture closed before any shot) are removed, as
    /// they are only clutter (PC-8).
    public static func unfinished(in parent: URL) -> [UnfinishedCapture] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: parent.path()) else { return [] }
        var found: [UnfinishedCapture] = []
        for name in names where UUID(uuidString: name) != nil {
            let folders = RawCaptureFolders(root: parent.appending(path: name, directoryHint: .isDirectory))
            let images = imageCount(in: folders)
            guard images > 0 else {
                try? manager.removeItem(at: folders.root)
                continue
            }
            let values = try? folders.root.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values?.contentModificationDate ?? .distantPast
            let size = bytes(in: folders.root)
            found.append(UnfinishedCapture(folders: folders, images: images, bytes: size, modified: modified))
        }
        return found.sorted { $0.modified != $1.modified ? $0.modified > $1.modified : $0.id < $1.id }
    }

    /// The file name for an exported raw capture, for example "Bracket raw capture.zip"
    /// (FR-7.5). Characters that folders on the phone or on Windows do not allow are
    /// replaced with "-", as for model exports.
    public static func exportName(for scanName: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var cleaned = String.UnicodeScalarView()
        for scalar in scanName.unicodeScalars {
            cleaned.append(forbidden.contains(scalar) ? "-" : scalar)
        }
        let trimmed = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "ScanLab" : trimmed) + " raw capture.zip"
    }

    /// Removes a capture folder and everything in it. A folder already gone is fine.
    public static func discard(_ folders: RawCaptureFolders) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: folders.root.path()) else { return }
        do {
            try manager.removeItem(at: folders.root)
        } catch {
            throw PhotoCaptureError.from(error)
        }
    }
}
