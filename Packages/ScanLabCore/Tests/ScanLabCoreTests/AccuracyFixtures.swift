import Foundation

@testable import ScanLabCore

/// Shapes, transforms and scans with exactly known errors, shared by the accuracy
/// tests. Everything is in metres unless a name says otherwise.
enum AccuracyFixtures {
    /// A small stand-in for the reference object: a 120 × 80 × 8 mm plate with a tall
    /// tower at the back left, a post at the front right, a low 5 mm step and a thin
    /// 2 mm rib. Like the real object, it looks different from every side.
    static let object: Mesh = {
        var builder = MeshBuilder()
        addBox(&builder, from: Vec3(0, 0, 0), to: Vec3(0.12, 0.08, 0.008), withBottom: true)
        addBox(&builder, from: Vec3(0.01, 0.05, 0.008), to: Vec3(0.03, 0.074, 0.068))
        addBox(&builder, from: Vec3(0.09, 0.01, 0.008), to: Vec3(0.10, 0.02, 0.02))
        addBox(&builder, from: Vec3(0.05, 0.01, 0.008), to: Vec3(0.08, 0.03, 0.013))
        addBox(&builder, from: Vec3(0.11, 0.04, 0.008), to: Vec3(0.112, 0.07, 0.018))
        return builder.mesh
    }()

    /// The feature table for `object`, with regions in millimetres as in the real
    /// table: the rib and step are small, the tower and post medium, the plate large.
    static let table = FeatureTable(features: [
        feature("R1", .length, 2, .small, [109.75, 39.75, 7.75, 112.25, 70.25, 18.25]),
        feature("S1", .step, 5, .small, [49.75, 9.75, 7.75, 80.25, 30.25, 13.25]),
        feature("T1", .length, 20, .medium, [9.75, 49.75, 7.75, 30.25, 74.25, 68]),
        feature("P1", .length, 10, .medium, [89.75, 9.75, 7.75, 100.25, 20.25, 20.25]),
        feature("L1", .length, 120, .large, [0, 0, 0, 120, 80, 8.25]),
    ])

    static let reference = ReferenceObject(mesh: object, table: table)

    /// Built once per test run: preparing is the slowest part of a small test.
    static let surface = Result { try ReferenceSurface(reference, sampleCount: 1500) }

    /// Settings that keep the tests fast in a debug build.
    static var quickSettings: AlignmentSettings {
        var settings = AlignmentSettings()
        settings.screeningPoints = 120
        settings.refinedStarts = 5
        settings.coarsePoints = 250
        settings.coarseIterations = 8
        settings.finePoints = 1500
        settings.fineIterations = 30
        return settings
    }

    static func request(_ surface: ReferenceSurface, scanPoints: Int = 3000) -> AccuracyRequest {
        var request = AccuracyRequest(
            scanID: UUID(), surface: surface, caliperValuesEntered: 3,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        request.alignment = quickSettings
        request.scanPoints = scanPoints
        return request
    }

    /// A turn of 35 degrees about a slanted axis plus a move of about 37 cm: a scan
    /// lying anywhere in the room.
    static let misplacement = Transform(
        rotation: Matrix3.rotation(axis: Vec3(1, 2, 3), angle: 35 * .pi / 180),
        translation: Vec3(0.3, -0.2, 0.15))

    /// Points spread over `mesh`, each pushed `offset` metres outwards along the surface
    /// direction plus random noise of the given standard deviation, then moved by
    /// `transform`. Also returns where each point would sit with no move (`truth`).
    static func scan(
        of mesh: Mesh, count: Int, offset: Double = 0, noise: Double = 0, transform: Transform = .identity
    ) -> (points: [SurfacePoint], truth: [Vec3]) {
        var random = SeededRandom(seed: 42)
        let samples = SurfaceSampler.sample(mesh, count: count, seed: 7)
        var points: [SurfacePoint] = []
        var truth: [Vec3] = []
        for sample in samples {
            let push = offset + noise * gaussian(&random)
            let position = sample.position + sample.normal * push
            truth.append(position)
            let moved = transform.apply(to: position)
            points.append(SurfacePoint(position: moved, normal: transform.rotation * sample.normal))
        }
        return (points, truth)
    }

    /// A normally distributed random number (mean 0, standard deviation 1), by the
    /// Box–Muller method.
    static func gaussian(_ random: inout SeededRandom) -> Double {
        let first = max(random.unit(), 1e-12)
        let second = random.unit()
        return (-2 * log(first)).squareRoot() * cos(2 * .pi * second)
    }

    /// The largest distance between matching points, in millimetres.
    static func largestGapMillimetres(_ first: [Vec3], _ second: [Vec3]) -> Double {
        zip(first, second).map { ($0 - $1).length }.max().map { $0 * 1000 } ?? .infinity
    }

    /// A ball of the given radius made of `rings` × `segments` patches.
    static func sphere(radius: Double, centre: Vec3 = .zero, rings: Int = 12, segments: Int = 24) -> Mesh {
        var builder = MeshBuilder()
        func spot(_ ring: Int, _ segment: Int) -> Vec3 {
            let polar = Double.pi * Double(ring) / Double(rings)
            let around = 2 * Double.pi * Double(segment) / Double(segments)
            return centre + Vec3(sin(polar) * cos(around), sin(polar) * sin(around), cos(polar)) * radius
        }
        for ring in 0..<rings {
            for segment in 0..<segments {
                let corners = [spot(ring, segment), spot(ring + 1, segment), spot(ring + 1, segment + 1)]
                let outward = (corners[0] + corners[1] + corners[2]) / 3 - centre
                builder.triangle(corners[0], corners[1], corners[2], outward: outward)
                let others = [spot(ring, segment), spot(ring + 1, segment + 1), spot(ring, segment + 1)]
                builder.triangle(others[0], others[1], others[2], outward: outward)
            }
        }
        return builder.mesh
    }

    /// A flat square `size` metres across at height `height`, facing up.
    static func floor(size: Double, height: Double, centre: Vec3) -> Mesh {
        var builder = MeshBuilder()
        let half = size / 2
        let corners = [
            Vec3(-half, -half, 0), Vec3(half, -half, 0), Vec3(half, half, 0), Vec3(-half, half, 0),
        ].map { $0 + Vec3(centre.x, centre.y, height) }
        builder.quad(corners, outward: Vec3(0, 0, 1))
        return builder.mesh
    }

    /// A box from `low` to `high`, closed.
    static func box(from low: Vec3, to high: Vec3) -> Mesh {
        var builder = MeshBuilder()
        addBox(&builder, from: low, to: high, withBottom: true)
        return builder.mesh
    }

    private static func addBox(_ builder: inout MeshBuilder, from low: Vec3, to high: Vec3, withBottom: Bool = false) {
        let corners: [Vec3] = (0..<8).map { (index: Int) -> Vec3 in
            Vec3(
                index & 1 == 0 ? low.x : high.x, (index >> 1) & 1 == 0 ? low.y : high.y,
                (index >> 2) & 1 == 0 ? low.z : high.z)
        }
        var sides: [([Int], Vec3)] = [
            ([4, 5, 7, 6], Vec3(0, 0, 1)), ([0, 1, 5, 4], Vec3(0, -1, 0)), ([2, 3, 7, 6], Vec3(0, 1, 0)),
            ([0, 2, 6, 4], Vec3(-1, 0, 0)), ([1, 3, 7, 5], Vec3(1, 0, 0)),
        ]
        if withBottom {
            sides.append(([0, 1, 3, 2], Vec3(0, 0, -1)))
        }
        for (indices, outward) in sides {
            builder.quad(indices.map { corners[$0] }, outward: outward)
        }
    }

    /// A feature whose region runs from the first three numbers to the last three (mm).
    private static func feature(
        _ id: String, _ kind: FeatureKind, _ size: Double, _ sizeClass: SizeClass, _ region: [Double]
    ) -> ReferenceFeature {
        let box = Box(minimum: Vec3(region[0], region[1], region[2]), maximum: Vec3(region[3], region[4], region[5]))
        return ReferenceFeature(
            id: id, kind: kind, summary: "Test feature \(id)", designValue: size, sizeClass: sizeClass, region: box)
    }

    /// The repository's own files, found from this source file's location.
    static func repositoryFile(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ScanLabCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // ScanLabCore
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repository root
            .appending(path: path)
    }

    /// The real reference object, loaded once per test run.
    static let realReference = Result {
        try ReferenceObject.load(
            stlData: Data(contentsOf: repositoryFile("reference-object/output/reference-object.stl")),
            featureTableData: Data(contentsOf: repositoryFile("reference-object/output/feature-table.json")))
    }
}
