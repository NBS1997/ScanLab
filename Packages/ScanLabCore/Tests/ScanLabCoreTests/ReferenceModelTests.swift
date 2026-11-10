import Foundation
import Testing

@testable import ScanLabCore

@Suite("Reference model")
struct ReferenceModelTests {
    @Test("the real reference object loads: shape in metres and every feature")
    func realReference() throws {
        let reference = try AccuracyFixtures.realReference.get()
        let size = try #require(reference.mesh.boundingBox?.size)
        #expect(isClose(size, Vec3(0.159276, 0.105, 0.108), tolerance: 1e-5))
        // Corners shared between faces were merged: far fewer corners than 3 per face.
        #expect(reference.mesh.vertexCount < reference.mesh.faceCount)
        let table = reference.table
        #expect(table.version == 1)
        #expect(table.features.count == 26)
        #expect(table.skippedFeatures == 0)
        #expect(table.smallLimit == 5 && table.mediumLimit == 30)
        let hole = try #require(table.feature("H2"))
        #expect(hole.kind == .hole && hole.unit == .millimetres && hole.sizeClass == .small)
        #expect(hole.designValue == 5 && hole.region.minimum == Vec3(99.25, 37.25, 0))
        #expect(table.feature("A2")?.unit == .degrees)
        #expect(Set(table.features.map(\.sizeClass)) == Set(SizeClass.allCases))
    }

    @Test("the feature table is read forgivingly")
    func tolerantTable() throws {
        let json = """
            {"features": [
              {"id": "X1", "kind": "spline", "designValue": 4, "unit": "mm", "sizeClass": "small",
               "region": {"min": [0, 0, 0], "max": [1, 1, 1]}, "extra": true},
              {"id": "X2", "kind": "hole", "unit": "mm"},
              {"id": "X3", "kind": "hole", "designValue": 4, "unit": "inch", "sizeClass": "small",
               "region": {"min": [0, 0, 0], "max": [1, 1, 1]}}
            ]}
            """
        let table = try FeatureTable.decode(Data(json.utf8))
        #expect(table.features.map(\.id) == ["X1"])
        #expect(table.features[0].kind == .other)
        #expect(table.features[0].summary == "X1")
        #expect(table.features[0].sizeMillimetres == 4)
        #expect(table.skippedFeatures == 2)
        #expect(table.version == 1 && table.smallLimit == 5)
    }

    @Test("a table that is not a table, or repeats an ID, is refused")
    func badTables() {
        #expect(throws: ReferenceError.self) { try FeatureTable.decode(Data("[]".utf8)) }
        #expect(throws: ReferenceError.self) { try FeatureTable.decode(Data(#"{"version": 1}"#.utf8)) }
        let feature =
            #"{"id":"A","kind":"hole","designValue":1,"unit":"mm","sizeClass":"small","#
            + #""region":{"min":[0,0,0],"max":[1,1,1]}}"#
        let twice = Data(#"{"features":[\#(feature),\#(feature)]}"#.utf8)
        #expect(throws: ReferenceError.malformedTable("two features share an ID")) { try FeatureTable.decode(twice) }
    }

    @Test("size class labels come from the table's limits")
    func labels() {
        let table = FeatureTable(smallLimit: 5, mediumLimit: 30.5, features: [])
        #expect(table.label(for: .small) == "Small (up to 5 mm)")
        #expect(table.label(for: .medium) == "Medium (5–30.5 mm)")
        #expect(table.label(for: .large) == "Large (over 30.5 mm)")
        #expect(SizeClass.small < .medium && SizeClass.medium < .large)
        #expect(FeatureKind.allCases.allSatisfy { !$0.groupTitle.isEmpty })
        #expect(SizeClass.allCases.map(\.displayName) == ["Small", "Medium", "Large"])
    }

    @Test("binary STL reads back the mesh, merging shared corners, in metres")
    func stlRoundTrip() throws {
        let cube = TestMeshes.cube(size: 0.05)
        let data = try MeshFiles.stlData(for: cube)
        let read = try MeshFiles.parseBinarySTL(data, unit: .millimetres)
        #expect(read.faceCount == 12)
        #expect(read.vertexCount == 8)
        #expect(isClose(read.volume, cube.volume, tolerance: 1e-12))
        #expect(read.openEdgeCount == 0)
    }

    @Test("short, text or broken STL files are refused")
    func badSTL() throws {
        #expect(throws: MeshFileError.self) { try MeshFiles.parseBinarySTL(Data(count: 20), unit: .millimetres) }
        let text = Data(("solid cube\n" + String(repeating: " ", count: 100)).utf8)
        #expect(throws: MeshFileError.self) { try MeshFiles.parseBinarySTL(text, unit: .millimetres) }
        var broken = try MeshFiles.stlData(for: TestMeshes.cube())
        broken.replaceSubrange(96..<100, with: Float.nan.bitPattern.littleEndianBytes)
        #expect(throws: MeshFileError.self) { try MeshFiles.parseBinarySTL(broken, unit: .millimetres) }
    }

    @Test("loading reports a damaged shape or an empty one")
    func loadErrors() throws {
        let table = try Data(contentsOf: AccuracyFixtures.repositoryFile("reference-object/output/feature-table.json"))
        #expect(throws: ReferenceError.self) { try ReferenceObject.load(stlData: Data(), featureTableData: table) }
        let empty = try MeshFiles.stlData(for: .empty)
        #expect(throws: ReferenceError.degenerateShape) {
            try ReferenceObject.load(stlData: empty, featureTableData: table)
        }
        #expect(ReferenceError.degenerateShape.errorDescription?.isEmpty == false)
        #expect(ReferenceError.unknownFeature("Q9").errorDescription?.contains("Q9") == true)
    }
}

extension UInt32 {
    /// The four bytes of the number, smallest first.
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian) { Array($0) }
    }
}
