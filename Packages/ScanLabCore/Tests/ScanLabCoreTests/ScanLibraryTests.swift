import Foundation
import Testing

@testable import ScanLabCore

/// A library over a memory store with a fixed clock in UTC, plus its log.
private struct Fixture {
    let store = MemoryScanStore()
    let log = MemoryLog()
    let library: ScanLibrary

    init(available: Int64? = nil, date: Date = fixedDate) {
        library = ScanLibrary(
            store: store, log: log, availableBytes: { available }, now: { date }, timeZone: .gmt)
    }

    func messages() async -> [String] {
        await log.readAll().events.map(\.message)
    }
}

@Suite("Scan library")
struct ScanLibraryTests {
    // MARK: add

    @Test("add saves the model, details and thumbnail, and logs it")
    func add() async throws {
        let fixture = Fixture()
        let mesh = TestMeshes.cube(size: 0.05)
        let scan = try await fixture.library.add(mesh: mesh, method: .sweep, detail: "full")
        #expect(scan.name == "Sweep 11 Nov 14:05")
        #expect(scan.method == .sweep)
        #expect(scan.detailLevel == "full")
        #expect(scan.faceCount == 12)
        #expect(scan.size.map { isClose($0, Vec3(0.05, 0.05, 0.05)) } == true)
        #expect(scan.createdAt == fixedDate)
        #expect(try await fixture.library.mesh(for: scan.id) == mesh)
        #expect(try await fixture.library.scan(scan.id) == scan)
        #expect(await fixture.library.thumbnail(for: scan.id)?.count == 160 * 160 * 4)
        let events = await fixture.log.readAll().events
        let added = try #require(events.last)
        #expect(added.message == "Scan added")
        #expect(added.category == "library")
        #expect(added.details["faces"] == "12")
    }

    @Test("add keeps a given name, trimmed")
    func addNamed() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .photos, name: "  Mount  ")
        #expect(scan.name == "Mount")
    }

    @Test("add with whole seconds only, so the date reads back exactly")
    func addRoundsDate() async throws {
        let fixture = Fixture(date: fixedDate.addingTimeInterval(0.75))
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .sample)
        #expect(scan.createdAt == fixedDate)
        #expect(scan.name == "Sample 11 Nov 14:05")
    }

    @Test("add an empty model: saved with no size")
    func addEmpty() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: .empty, method: .sample)
        #expect(scan.faceCount == 0)
        #expect(scan.size == nil)
        #expect(try await fixture.library.mesh(for: scan.id) == .empty)
    }

    @Test("add fails cleanly with noSpace and writes nothing")
    func addNoSpace() async throws {
        let fixture = Fixture(available: 1_000)
        await #expect(throws: StoreError.noSpace) {
            try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        }
        #expect(try await fixture.library.all().scans.isEmpty)
        let messages = await fixture.messages()
        #expect(messages.contains("Not enough space"))
        #expect(messages.contains("Scan not added"))
    }

    @Test("add succeeds when there is room")
    func addWithRoom() async throws {
        let fixture = Fixture(available: 50_000_000)
        try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        #expect(try await fixture.library.all().scans.count == 1)
    }

    @Test("add refuses an empty name and a store failure, logging both")
    func addFailures() async throws {
        let fixture = Fixture()
        await #expect(throws: StoreError.emptyName) {
            try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep, name: "   ")
        }
        fixture.store.failWrites(with: .writeFailed("disk error"))
        await #expect(throws: StoreError.writeFailed("disk error")) {
            try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        }
        #expect(await fixture.messages().filter { $0 == "Scan not added" }.count == 2)
    }

    // MARK: all

    @Test("all lists scans newest first")
    func listOrder() async throws {
        let store = MemoryScanStore()
        let log = MemoryLog()
        for offset in [0.0, 120, 60] {
            let library = ScanLibrary(store: store, log: log, now: { fixedDate.addingTimeInterval(offset) })
            try await library.add(mesh: TestMeshes.cube(), method: .sweep, name: "At \(Int(offset))")
        }
        let listing = try await ScanLibrary(store: store, log: log).all()
        #expect(listing.scans.map(\.name) == ["At 120", "At 60", "At 0"])
        #expect(listing.unreadable == 0)
    }

    @Test("an empty library lists nothing")
    func listEmpty() async throws {
        #expect(try await Fixture().library.all() == ScanListing())
    }

    @Test("a damaged manifest is skipped and counted, not fatal")
    func listCorrupt() async throws {
        let fixture = Fixture()
        try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        fixture.store.setManifestData(Data("{ broken".utf8), for: UUID())
        let listing = try await fixture.library.all()
        #expect(listing.scans.count == 1)
        #expect(listing.unreadable == 1)
        #expect(await fixture.messages().contains("Scan skipped"))
    }

    @Test("a manifest in the wrong folder is counted as unreadable")
    func listMismatchedIdentity() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        let stray = UUID()
        fixture.store.setManifestData(try ManifestCodec.encode(scan), for: stray)
        let listing = try await fixture.library.all()
        #expect(listing.scans.map(\.id) == [scan.id])
        #expect(listing.unreadable == 1)
        await #expect(throws: StoreError.self) { try await fixture.library.scan(stray) }
    }

    @Test("a store that cannot list is reported and logged")
    func listFailure() async throws {
        let log = MemoryLog()
        let library = ScanLibrary(store: FailingStore(), log: log)
        await #expect(throws: StoreError.readFailed("folder missing")) { try await library.all() }
        #expect(await log.readAll().events.last?.message == "Library could not be read")
    }

    // MARK: rename

    @Test("rename stores the trimmed name")
    func rename() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        let renamed = try await fixture.library.rename(scan.id, to: "  Kayak hull \n")
        #expect(renamed.name == "Kayak hull")
        #expect(try await fixture.library.scan(scan.id).name == "Kayak hull")
        #expect(await fixture.messages().last == "Scan renamed")
    }

    @Test("rename accepts exactly 80 characters")
    func renameLongest() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        let name = String(repeating: "é", count: 80)
        #expect(try await fixture.library.rename(scan.id, to: name).name == name)
    }

    @Test("rename refuses empty and overlong names and leaves the old name")
    func renameInvalid() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep, name: "Original")
        await #expect(throws: StoreError.emptyName) { try await fixture.library.rename(scan.id, to: " \t ") }
        await #expect(throws: StoreError.nameTooLong(maximum: 80)) {
            try await fixture.library.rename(scan.id, to: String(repeating: "a", count: 81))
        }
        #expect(try await fixture.library.scan(scan.id).name == "Original")
        #expect(await fixture.messages().last == "Scan not renamed")
    }

    @Test("rename of an unknown scan is notFound")
    func renameUnknown() async {
        let id = UUID()
        await #expect(throws: StoreError.notFound(id)) { try await Fixture().library.rename(id, to: "New") }
    }

    // MARK: delete and storage

    @Test("delete removes the scan and returns what it freed")
    func delete() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .photos)
        fixture.store.setRawCaptureBytes(5_000, for: scan.id)
        let before = try await fixture.library.storage(for: scan.id)
        #expect(before.rawCaptureBytes == 5_000)
        #expect(before.modelBytes > 0)
        let freed = try await fixture.library.delete(scan.id)
        #expect(freed == before)
        #expect(try await fixture.library.all().scans.isEmpty)
        await #expect(throws: StoreError.notFound(scan.id)) { try await fixture.library.mesh(for: scan.id) }
        #expect(await fixture.messages().contains("Scan deleted"))
    }

    @Test("delete of an unknown scan is notFound and logged")
    func deleteUnknown() async {
        let fixture = Fixture()
        let id = UUID()
        await #expect(throws: StoreError.notFound(id)) { try await fixture.library.delete(id) }
        #expect(await fixture.messages().last == "Scan not deleted")
    }

    @Test("delete that the store refuses keeps the scan")
    func deleteFailure() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .sweep)
        fixture.store.failWrites(with: .writeFailed("busy"))
        await #expect(throws: StoreError.writeFailed("busy")) { try await fixture.library.delete(scan.id) }
        #expect(try await fixture.library.all().scans.count == 1)
    }

    @Test("storage of an unknown scan is notFound")
    func storageUnknown() async {
        let fixture = Fixture()
        let id = UUID()
        await #expect(throws: StoreError.notFound(id)) { try await fixture.library.storage(for: id) }
        #expect(await fixture.messages().last == "Scan size not read")
    }

    @Test("storage totals model and raw capture")
    func storageTotal() {
        #expect(StorageUse(modelBytes: 10, rawCaptureBytes: 5).totalBytes == 15)
        #expect(StorageUse.none.totalBytes == 0)
    }

    // MARK: reference flag and reading

    @Test("setReference marks and unmarks a scan")
    func setReference() async throws {
        let fixture = Fixture()
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .photos)
        #expect(try await fixture.library.setReference(scan.id, true).isReference)
        #expect(try await fixture.library.scan(scan.id).isReference)
        #expect(try await fixture.library.setReference(scan.id, false).isReference == false)
    }

    @Test("setReference on an unknown scan, or with a failing store, is reported")
    func setReferenceFailures() async throws {
        let fixture = Fixture()
        let id = UUID()
        await #expect(throws: StoreError.notFound(id)) { try await fixture.library.setReference(id, true) }
        let scan = try await fixture.library.add(mesh: TestMeshes.cube(), method: .photos)
        fixture.store.failWrites(with: .noSpace)
        await #expect(throws: StoreError.noSpace) { try await fixture.library.setReference(scan.id, true) }
        #expect(try await fixture.library.scan(scan.id).isReference == false)
        #expect(await fixture.messages().last == "Reference mark not changed")
    }

    @Test("a damaged model file is reported as corrupt and logged")
    func damagedMesh() async throws {
        let log = MemoryLog()
        let store = DamagedMeshStore()
        let library = ScanLibrary(store: store, log: log)
        await #expect(throws: StoreError.corrupt("the model file is not a ScanLab model")) {
            try await library.mesh(for: UUID())
        }
        #expect(await log.readAll().events.last?.message == "Model could not be read")
        #expect(await library.thumbnail(for: UUID()) == nil)
    }
}

/// A store whose listing always fails.
private struct FailingStore: ScanStoring {
    func scanIDs() throws -> [UUID] { throw StoreError.readFailed("folder missing") }
    func manifestData(for id: UUID) throws -> Data { throw StoreError.notFound(id) }
    func meshData(for id: UUID) throws -> Data { throw StoreError.notFound(id) }
    func thumbnailData(for id: UUID) -> Data? { nil }
    func create(_ id: UUID, manifest: Data, mesh: Data, thumbnail: RGBAImage?) throws {}
    func replaceManifest(_ manifest: Data, for id: UUID) throws {}
    func remove(_ id: UUID) throws {}
    func storage(for id: UUID) throws -> StorageUse { .none }
}

/// A store that hands back rubbish for every model.
private struct DamagedMeshStore: ScanStoring {
    func scanIDs() throws -> [UUID] { [] }
    func manifestData(for id: UUID) throws -> Data { throw StoreError.notFound(id) }
    func meshData(for id: UUID) throws -> Data { Data("rubbish".utf8) }
    func thumbnailData(for id: UUID) -> Data? { nil }
    func create(_ id: UUID, manifest: Data, mesh: Data, thumbnail: RGBAImage?) throws {}
    func replaceManifest(_ manifest: Data, for id: UUID) throws {}
    func remove(_ id: UUID) throws {}
    func storage(for id: UUID) throws -> StorageUse { .none }
}
