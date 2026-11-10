import Foundation
import Testing

@testable import ScanLabCore

/// A store that keeps nothing and has no raw-capture support, to check the port's
/// default answers.
private struct BareStore: ScanStoring {
    func scanIDs() throws -> [UUID] { [] }
    func manifestData(for id: UUID) throws -> Data { throw StoreError.notFound(id) }
    func meshData(for id: UUID) throws -> Data { throw StoreError.notFound(id) }
    func thumbnailData(for id: UUID) -> Data? { nil }
    func create(_ id: UUID, manifest: Data, mesh: Data, thumbnail: RGBAImage?) throws {}
    func replaceManifest(_ manifest: Data, for id: UUID) throws {}
    func remove(_ id: UUID) throws {}
    func storage(for id: UUID) throws -> StorageUse { .none }
}

@Suite("Scan library raw capture")
struct ScanLibraryRawCaptureTests {
    private func folderWithPhotos(bytes: Int) throws -> URL {
        let folder = try TestMeshes.temporaryFolder()
        try Data(repeating: 3, count: bytes).write(to: folder.appending(path: "IMG_0000.HEIC"))
        return folder
    }

    @Test("keeping records the size in the manifest and the storage figure, and logs it")
    func keep() async throws {
        let store = MemoryScanStore()
        let log = MemoryLog()
        let library = ScanLibrary(store: store, log: log)
        let scan = try await library.add(mesh: TestMeshes.cube(size: 0.05), method: .photos, detail: "reduced")
        let folder = try folderWithPhotos(bytes: 50_000)
        defer { TestMeshes.cleanUp(folder) }

        let kept = try await library.keepRawCapture(scan.id, from: folder)
        let bytes = try #require(kept.rawCaptureBytes)
        #expect(bytes >= 50_000)
        #expect(try await library.scan(scan.id).rawCaptureBytes == bytes)
        #expect(try await library.storage(for: scan.id).rawCaptureBytes == bytes)
        #expect(await library.rawCaptureFolder(for: scan.id) == folder)
        let last = try #require(await log.readAll().events.last)
        #expect(last.message == "Raw capture kept")
        #expect(last.details["bytes"] == String(bytes))
    }

    @Test("discarding clears the size and frees the storage; discarding again is harmless")
    func discard() async throws {
        let library = ScanLibrary(store: MemoryScanStore(), log: MemoryLog())
        let scan = try await library.add(mesh: TestMeshes.cube(), method: .photos)
        let folder = try folderWithPhotos(bytes: 10_000)
        defer { TestMeshes.cleanUp(folder) }
        try await library.keepRawCapture(scan.id, from: folder)

        let cleared = try await library.discardRawCapture(scan.id)
        #expect(cleared.rawCaptureBytes == nil)
        #expect(try await library.scan(scan.id).rawCaptureBytes == nil)
        #expect(try await library.storage(for: scan.id).rawCaptureBytes == 0)
        #expect(await library.rawCaptureFolder(for: scan.id) == nil)
        #expect(try await library.discardRawCapture(scan.id).rawCaptureBytes == nil)
    }

    @Test("deleting a scan drops its raw capture too")
    func deleteDropsRaw() async throws {
        let store = MemoryScanStore()
        let library = ScanLibrary(store: store, log: MemoryLog())
        let scan = try await library.add(mesh: TestMeshes.cube(), method: .photos)
        let folder = try folderWithPhotos(bytes: 10_000)
        defer { TestMeshes.cleanUp(folder) }
        try await library.keepRawCapture(scan.id, from: folder)
        let freed = try await library.delete(scan.id)
        #expect(freed.rawCaptureBytes >= 10_000)
        #expect(store.rawCaptureFolder(for: scan.id) == nil)
    }

    @Test("keeping for an unknown scan fails with notFound and is logged")
    func keepUnknown() async throws {
        let log = MemoryLog()
        let library = ScanLibrary(store: MemoryScanStore(), log: log)
        let id = UUID()
        await #expect(throws: StoreError.notFound(id)) {
            try await library.keepRawCapture(id, from: URL(filePath: "/nowhere"))
        }
        await #expect(throws: StoreError.notFound(id)) {
            try await library.discardRawCapture(id)
        }
        let messages = await log.readAll().events.map(\.message)
        #expect(messages == ["Raw capture not kept", "Raw capture not discarded"])
    }

    @Test("a full store refuses to keep and the manifest is unchanged")
    func keepNoSpace() async throws {
        let store = MemoryScanStore()
        let library = ScanLibrary(store: store, log: MemoryLog())
        let scan = try await library.add(mesh: TestMeshes.cube(), method: .photos)
        store.failWrites(with: .noSpace)
        await #expect(throws: StoreError.noSpace) {
            try await library.keepRawCapture(scan.id, from: URL(filePath: "/nowhere"))
        }
        await #expect(throws: StoreError.noSpace) {
            try await library.discardRawCapture(scan.id)
        }
        store.failWrites(with: nil)
        #expect(try await library.scan(scan.id).rawCaptureBytes == nil)
    }

    @Test("a store without raw-capture support says so")
    func bareStore() throws {
        let store = BareStore()
        #expect(throws: StoreError.writeFailed("this storage cannot keep raw captures")) {
            try store.attachRawCapture(from: URL(filePath: "/x"), to: UUID())
        }
        try store.removeRawCapture(for: UUID())
        #expect(store.rawCaptureFolder(for: UUID()) == nil)
        #expect(try store.scanIDs().isEmpty)
        #expect(store.thumbnailData(for: UUID()) == nil)
        #expect(try store.storage(for: UUID()) == .none)
    }
}
