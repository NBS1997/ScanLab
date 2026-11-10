import Foundation
import Testing

@testable import ScanLabCore

@Suite("Accuracy report storage")
struct AccuracyStorageTests {
    private let report = Data(#"{"report": 1}"#.utf8)

    @Test("attaching a report stores it and sets the flag, once")
    func attach() async throws {
        let store = MemoryScanStore()
        let log = MemoryLog()
        let library = ScanLibrary(store: store, log: log)
        let scan = try await library.add(mesh: TestMeshes.cube(size: 0.05), method: .sweep)
        #expect(try await library.reportData(for: scan.id) == nil)
        let updated = try await library.attachReport(report, to: scan.id)
        #expect(updated.hasAccuracyReport)
        #expect(try await library.scan(scan.id).hasAccuracyReport)
        #expect(try await library.reportData(for: scan.id) == report)
        let newer = Data(#"{"report": 2}"#.utf8)
        try await library.attachReport(newer, to: scan.id)
        #expect(try await library.reportData(for: scan.id) == newer)
        #expect(await log.readAll().events.last?.message == "Accuracy report saved")
    }

    @Test("a report for a missing scan, or on full storage, is refused and logged")
    func failures() async throws {
        let store = MemoryScanStore()
        let log = MemoryLog()
        let library = ScanLibrary(store: store, log: log, availableBytes: { 100 })
        let missing = UUID()
        await #expect(throws: StoreError.notFound(missing)) {
            try await library.attachReport(report, to: missing)
        }
        #expect(await log.readAll().events.last?.message == "Accuracy report not saved")
        await #expect(throws: StoreError.notFound(missing)) {
            try await library.reportData(for: missing)
        }
        #expect(await log.readAll().events.last?.message == "Accuracy report not read")
    }

    @Test("a report is refused when the phone is full, and the flag stays off")
    func noSpace() async throws {
        let store = MemoryScanStore()
        let roomy = ScanLibrary(store: store, log: MemoryLog())
        let scan = try await roomy.add(mesh: TestMeshes.cube(size: 0.05), method: .photos)
        let full = ScanLibrary(store: store, log: MemoryLog(), availableBytes: { 10 })
        await #expect(throws: StoreError.noSpace) { try await full.attachReport(report, to: scan.id) }
        #expect(try await roomy.scan(scan.id).hasAccuracyReport == false)
        #expect(try store.reportData(for: scan.id) == nil)
    }

    @Test("deleting a scan removes its report; stores without reports refuse to keep one")
    func deleteAndFallback() async throws {
        let store = MemoryScanStore()
        let library = ScanLibrary(store: store, log: MemoryLog())
        let scan = try await library.add(mesh: TestMeshes.cube(size: 0.05), method: .sweep)
        try await library.attachReport(report, to: scan.id)
        try await library.delete(scan.id)
        #expect(throws: StoreError.notFound(scan.id)) { try store.reportData(for: scan.id) }
        store.failWrites(with: .noSpace)
        #expect(throws: StoreError.self) { try store.replaceReport(report, for: scan.id) }
        let bare = BareStore()
        #expect(try bare.reportData(for: scan.id) == nil)
        #expect(throws: StoreError.self) { try bare.replaceReport(report, for: scan.id) }
    }
}

/// A store written without accuracy reports, relying on the fallbacks.
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
