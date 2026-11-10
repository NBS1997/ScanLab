import Foundation
import Testing

@testable import ScanLabCore

@Suite("Export detail levels and file names")
struct ExportDetailTests {
    @Test("each level has a name, a summary and the agreed face limit")
    func levels() {
        #expect(ExportDetail.allCases == [.full, .fusionFriendly, .light])
        #expect(ExportDetail.allCases.map(\.displayName) == ["Full", "Fusion-friendly", "Light"])
        #expect(ExportDetail.allCases.map(\.faceLimit) == [nil, 10_000, 5_000])
        #expect(ExportDetail.allCases.allSatisfy { !$0.summary.isEmpty && $0.id == $0.rawValue })
    }

    @Test("targets never exceed the mesh's own face count")
    func targets() {
        let sample = SampleMeshes.stepBlock()
        #expect(ExportDetail.full.targetFaces(for: sample) == 19_840)
        #expect(ExportDetail.fusionFriendly.targetFaces(for: sample) == 10_000)
        #expect(ExportDetail.light.targetFaces(for: sample) == 5_000)
        let cube = TestMeshes.cube()
        #expect(ExportDetail.light.targetFaces(for: cube) == 12)
        #expect(ExportDetail.full.targetFaces(for: .empty) == 0)
    }

    @Test("Fusion-friendly has at most 10,000 faces and Light at most 5,000")
    func prepared() throws {
        let grid = TestMeshes.grid(cells: 60)
        #expect(grid.faceCount == 7_200)
        #expect(try ExportDetail.full.prepare(grid) == grid)
        #expect(try ExportDetail.fusionFriendly.prepare(grid) == grid)
        #expect(try ExportDetail.light.prepare(grid).faceCount <= 5_000)
        #expect(try SampleResults.fusion.get().faceCount <= 10_000)
    }

    @Test("a small mesh is exported as it is at every level")
    func smallMesh() throws {
        let cube = TestMeshes.cube()
        for detail in ExportDetail.allCases {
            #expect(try detail.prepare(cube) == cube)
        }
    }

    @Test("file names carry the level and the extension")
    func fileNames() {
        let name = ExportNaming.fileName(for: "Sample stepped block", detail: .fusionFriendly, format: .stl)
        #expect(name == "Sample stepped block (Fusion-friendly).stl")
        #expect(ExportNaming.fileName(for: "Bracket", detail: .light, format: .obj) == "Bracket (Light).obj")
    }

    @Test("characters that folders do not allow are replaced")
    func unsafeCharacters() {
        let name = ExportNaming.fileName(for: "a/b:c*d?\"e\nf", detail: .full, format: .stl)
        #expect(name == "a-b-c-d--e-f (Full).stl")
    }

    @Test("a blank name falls back to a default")
    func blankName() {
        #expect(ExportNaming.fileName(for: "   ", detail: .full, format: .obj) == "ScanLab model (Full).obj")
    }
}
