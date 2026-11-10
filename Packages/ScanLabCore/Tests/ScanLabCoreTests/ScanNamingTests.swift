import Foundation
import Testing

@testable import ScanLabCore

@Suite("Scan names and storage sizes")
struct ScanNamingTests {
    @Test("default names are the method and the date in 24-hour time")
    func defaultNames() {
        #expect(ScanNaming.defaultName(method: .sweep, date: fixedDate, timeZone: .gmt) == "Sweep 11 Nov 14:05")
        #expect(ScanNaming.defaultName(method: .photos, date: fixedDate, timeZone: .gmt) == "Photos 11 Nov 14:05")
        let sydney = TimeZone(identifier: "Australia/Sydney") ?? .gmt
        // 14:05 UTC is 01:05 the next morning in Sydney in summer time.
        #expect(ScanNaming.defaultName(method: .sample, date: fixedDate, timeZone: sydney) == "Sample 12 Nov 01:05")
        #expect(ScanNaming.shortDate(fixedDate, timeZone: .gmt) == "11 Nov")
    }

    @Test("names are trimmed")
    func trimmed() throws {
        #expect(try ScanNaming.validated("  Bracket\n") == "Bracket")
        #expect(try ScanNaming.validated("A") == "A")
    }

    @Test("empty names are refused", arguments: ["", "   ", "\n\t"])
    func empty(name: String) {
        #expect(throws: StoreError.emptyName) { try ScanNaming.validated(name) }
    }

    @Test("names over 80 characters are refused; spaces trimmed first")
    func tooLong() throws {
        #expect(throws: StoreError.nameTooLong(maximum: 80)) {
            try ScanNaming.validated(String(repeating: "x", count: 81))
        }
        let padded = "  " + String(repeating: "x", count: 80) + "  "
        #expect(try ScanNaming.validated(padded).count == 80)
    }

    @Test(
        "storage sizes count 1,000 bytes to a kilobyte",
        arguments: [
            (Int64(0), "0 bytes"), (1, "1 byte"), (999, "999 bytes"), (1_000, "1.0 KB"), (4_800_000, "4.8 MB"),
            (9_960_000, "10 MB"), (212_000_000, "212 MB"), (1_234_000_000, "1.2 GB"), (-5, "0 bytes"),
            (2_500_000_000_000, "2.5 TB"), (1_234_567_000_000_000, "1,235 TB"),
        ] as [(Int64, String)])
    func storage(bytes: Int64, expected: String) {
        #expect(Units.storage(bytes) == expected)
    }
}

@Suite("3D view geometry")
struct ViewerGeometryTests {
    @Test("each face gets its own three corners, centred on the origin")
    func corners() throws {
        let cube = TestMeshes.cube(size: 2).transformed(by: .moving(by: Vec3(5, 5, 5)))
        let geometry = ViewerGeometry(cube)
        #expect(geometry.cornerCount == 36)
        #expect(geometry.positions.count == 108)
        #expect(geometry.normals.count == 108)
        #expect(geometry.positions.allSatisfy { abs($0) <= 1 })
        #expect(isClose(geometry.radius, 3.0.squareRoot()))
    }

    @Test("normals have length 1 and match their face")
    func normals() throws {
        let geometry = ViewerGeometry(TestMeshes.cube())
        let cube = TestMeshes.cube()
        for corner in 0..<geometry.cornerCount {
            let normal = Vec3(
                Double(geometry.normals[corner * 3]), Double(geometry.normals[corner * 3 + 1]),
                Double(geometry.normals[corner * 3 + 2]))
            #expect(isClose(normal.length, 1, tolerance: 1e-6))
            #expect(isClose(normal, cube.faceNormal(corner / 3), tolerance: 1e-6))
        }
    }

    @Test("an empty model has nothing to draw and no size")
    func empty() {
        let geometry = ViewerGeometry(.empty)
        #expect(geometry.cornerCount == 0)
        #expect(geometry.radius == 0)
    }
}

@Suite("Memory scan store")
struct MemoryScanStoreTests {
    @Test("unknown scans are notFound for every read and change")
    func unknown() {
        let store = MemoryScanStore()
        let id = UUID()
        #expect(throws: StoreError.notFound(id)) { try store.manifestData(for: id) }
        #expect(throws: StoreError.notFound(id)) { try store.meshData(for: id) }
        #expect(throws: StoreError.notFound(id)) { try store.replaceManifest(Data(), for: id) }
        #expect(throws: StoreError.notFound(id)) { try store.remove(id) }
        #expect(throws: StoreError.notFound(id)) { try store.storage(for: id) }
        #expect(store.thumbnailData(for: id) == nil)
    }

    @Test("storage counts manifest, model and thumbnail, plus raw capture")
    func storage() throws {
        let store = MemoryScanStore()
        let id = UUID()
        let picture = RGBAImage(width: 2, height: 2)
        try store.create(id, manifest: Data(count: 10), mesh: Data(count: 100), thumbnail: picture)
        store.setRawCaptureBytes(7, for: id)
        #expect(try store.storage(for: id) == StorageUse(modelBytes: 126, rawCaptureBytes: 7))
        #expect(try store.scanIDs() == [id])
    }

    @Test("a failing store refuses writes until told to succeed")
    func failing() throws {
        let store = MemoryScanStore()
        let id = UUID()
        store.failWrites(with: .noSpace)
        #expect(throws: StoreError.noSpace) {
            try store.create(id, manifest: Data(), mesh: Data(), thumbnail: nil)
        }
        store.failWrites(with: nil)
        try store.create(id, manifest: Data(), mesh: Data(), thumbnail: nil)
        #expect(try store.scanIDs() == [id])
    }
}
