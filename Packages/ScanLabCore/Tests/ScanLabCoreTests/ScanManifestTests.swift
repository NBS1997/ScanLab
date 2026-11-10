import Foundation
import Testing

@testable import ScanLabCore

/// 11 November 2026, 14:05:30 UTC.
let fixedDate = Date(timeIntervalSince1970: 1_794_405_930)

@Suite("Scan manifest")
struct ScanManifestTests {
    @Test("a manifest round-trips through JSON with every field")
    func roundTrip() throws {
        let scan = Scan(
            name: "Hull section", method: .photos, createdAt: fixedDate, detailLevel: "reduced",
            faceCount: 48_200, size: Vec3(0.142, 0.096, 0.071), isReference: true, hasAccuracyReport: true,
            rawCaptureBytes: 196_000_000)
        let decoded = try ManifestCodec.decode(try ManifestCodec.encode(scan))
        #expect(decoded == scan)
        #expect(decoded.version == Scan.currentVersion)
    }

    @Test("optional fields left empty stay empty")
    func optionalsStayEmpty() throws {
        let scan = Scan(name: "Empty", method: .sample, createdAt: fixedDate)
        let data = try ManifestCodec.encode(scan)
        let text = try #require(String(bytes: data, encoding: .utf8))
        #expect(!text.contains("rawCaptureBytes"))
        #expect(!text.contains("detailLevel"))
        #expect(try ManifestCodec.decode(data) == scan)
    }

    @Test("an older manifest without the newer fields reads with defaults")
    func olderManifest() throws {
        let id = UUID()
        let json = """
            {"id": "\(id.uuidString)", "name": "Old", "method": "sweep", "createdAt": "2026-11-11T14:05:30Z"}
            """
        let scan = try ManifestCodec.decode(Data(json.utf8))
        #expect(scan.id == id)
        #expect(scan.version == 1)
        #expect(scan.faceCount == 0)
        #expect(scan.size == nil)
        #expect(!scan.isReference)
        #expect(!scan.hasAccuracyReport)
        #expect(scan.createdAt == fixedDate)
    }

    @Test("fields added by a later build are ignored")
    func extraFields() throws {
        let id = UUID()
        let json = """
            {"id": "\(id.uuidString)", "name": "New", "method": "photos", "createdAt": "2026-11-11T14:05:30Z",
             "version": 7, "futureThing": {"a": [1, 2]}, "size": [0.1, 0.2, 0.3]}
            """
        let scan = try ManifestCodec.decode(Data(json.utf8))
        #expect(scan.version == 7)
        #expect(scan.size == Vec3(0.1, 0.2, 0.3))
    }

    @Test(
        "damaged or incomplete manifests are reported as corrupt",
        arguments: [
            "not json",
            "{\"name\": \"No identity\", \"method\": \"sweep\", \"createdAt\": \"2026-11-11T14:05:30Z\"}",
            "{\"id\": \"\(UUID().uuidString)\", \"name\": \"X\", \"method\": \"pen\", \"createdAt\": \"2026-11-11\"}",
            "",
        ])
    func corrupt(json: String) {
        #expect(throws: StoreError.self) {
            try ManifestCodec.decode(Data(json.utf8))
        }
    }

    @Test("a size that is not three numbers is corrupt")
    func badSize() {
        let json = """
            {"id": "\(UUID().uuidString)", "name": "X", "method": "sweep", "createdAt": "2026-11-11T14:05:30Z",
             "size": [1, 2]}
            """
        #expect(throws: StoreError.corrupt("the scan details could not be read")) {
            try ManifestCodec.decode(Data(json.utf8))
        }
    }

    @Test("capture methods have display names")
    func methodNames() {
        #expect(CaptureMethod.allCases.map(\.displayName) == ["Sweep", "Photos", "Sample"])
    }

    @Test("every store error has a readable description")
    func errorDescriptions() {
        let errors: [StoreError] = [
            .notFound(UUID()), .noSpace, .emptyName, .nameTooLong(maximum: 80), .writeFailed("disk"),
            .readFailed("disk"), .corrupt("bad"),
        ]
        for error in errors {
            let text = error.errorDescription ?? ""
            #expect(text.count > 10)
        }
        #expect(StoreError.noSpace.errorDescription?.contains("nothing was saved") == true)
        #expect(StoreError.nameTooLong(maximum: 80).errorDescription?.contains("80") == true)
    }
}
