import Foundation
import Testing

@testable import ScanLabCore

struct VoxelVolumeTests {
    @Test func negativePositionsFindTheirOwnCube() {
        var volume = VoxelVolume(voxelSize: 0.004, maximumBlocks: 10)
        let index = VoxelIndex(-1, -9, 17)
        volume.add(distance: 0.5, weight: 1, to: index, maximumWeight: 64)
        #expect(volume.distance(at: index, minimumWeight: 1) == 0.5)
        #expect(volume.distance(at: VoxelIndex(-2, -9, 17), minimumWeight: 0) == nil)
        #expect(volume.distance(at: VoxelIndex(7, -9, 17), minimumWeight: 0) == nil)
        #expect(volume.index(of: volume.centre(of: index)) == index)
    }

    @Test func onePictureChangesACubeOnce() {
        var volume = VoxelVolume(voxelSize: 0.004, maximumBlocks: 10)
        let index = VoxelIndex(3, 3, 3)
        volume.add(distance: 1, weight: 1, to: index, maximumWeight: 64)
        volume.add(distance: -1, weight: 1, to: index, maximumWeight: 64)
        #expect(volume.distance(at: index, minimumWeight: 1.5) == nil)
        volume.beginPicture()
        volume.add(distance: 0, weight: 1, to: index, maximumWeight: 64)
        // The average of 1 and 0, seen with weight 2.
        #expect(volume.distance(at: index, minimumWeight: 1.5) == 0.5)
    }

    @Test func weightStopsGrowingAtTheCap() {
        var volume = VoxelVolume(voxelSize: 0.004, maximumBlocks: 10)
        let index = VoxelIndex(0, 0, 0)
        for _ in 0..<10 {
            volume.beginPicture()
            volume.add(distance: 1, weight: 1, to: index, maximumWeight: 3)
        }
        #expect(volume.distance(at: index, minimumWeight: 3) == 1)
        #expect(volume.distance(at: index, minimumWeight: 3.5) == nil)
    }

    @Test func picturesNumbersWrapWithoutCrashing() {
        var volume = VoxelVolume(voxelSize: 0.004, maximumBlocks: 10)
        for _ in 0..<70_000 {
            volume.beginPicture()
        }
        volume.add(distance: 0.25, weight: 2, to: VoxelIndex(1, 1, 1), maximumWeight: 64)
        #expect(volume.distance(at: VoxelIndex(1, 1, 1), minimumWeight: 2) == 0.25)
    }

    @Test func seenCubesAreVisitedWithTheirPositions() {
        var volume = VoxelVolume(voxelSize: 0.004, maximumBlocks: 10)
        let indices = [VoxelIndex(-3, 0, 5), VoxelIndex(12, -20, 1)]
        for index in indices {
            volume.add(distance: 0.1, weight: 2, to: index, maximumWeight: 64)
        }
        volume.add(distance: 0.1, weight: 1, to: VoxelIndex(0, 0, 0), maximumWeight: 64)
        var visited: [VoxelIndex] = []
        volume.forEachSeen(minimumWeight: 1.5) { index, _ in visited.append(index) }
        #expect(Set(visited) == Set(indices))
    }
}

struct MeshPiecesTests {
    /// A flat square grid of `side` × `side` squares (2 triangles each), moved by `offset`.
    func grid(side: Int, offset: Vec3) -> (vertices: [Vec3], triangles: [Triangle]) {
        var vertices: [Vec3] = []
        var triangles: [Triangle] = []
        for row in 0...side {
            for column in 0...side {
                vertices.append(offset + Vec3(Double(column) * 0.01, Double(row) * 0.01, 0))
            }
        }
        for row in 0..<side {
            for column in 0..<side {
                let corner = row * (side + 1) + column
                triangles.append(Triangle(corner, corner + 1, corner + side + 2))
                triangles.append(Triangle(corner, corner + side + 2, corner + side + 1))
            }
        }
        return (vertices, triangles)
    }

    @Test func smallLoosePiecesAreDropped() throws {
        let big = grid(side: 8, offset: .zero)
        let small = grid(side: 1, offset: Vec3(1, 1, 1))
        let shift = big.vertices.count
        let mesh = try Mesh(
            vertices: big.vertices + small.vertices,
            triangles: big.triangles + small.triangles.map { Triangle($0.a + shift, $0.b + shift, $0.c + shift) })
        let result = MeshPieces.droppingSmallPieces(of: mesh, smallestFaces: 60)
        #expect(result.piecesDropped == 1)
        #expect(result.facesDropped == 2)
        #expect(result.mesh.faceCount == 128)
        #expect(result.mesh.vertexCount == 81)
        // Every remaining index points at a real corner.
        _ = try Mesh(vertices: result.mesh.vertices, triangles: result.mesh.triangles)
    }

    @Test func meshWithOnlyLargePiecesIsUnchanged() throws {
        let big = grid(side: 8, offset: .zero)
        let mesh = try Mesh(vertices: big.vertices, triangles: big.triangles)
        let result = MeshPieces.droppingSmallPieces(of: mesh, smallestFaces: 60)
        #expect(result.mesh.faceCount == mesh.faceCount)
        #expect(result.piecesDropped == 0)
    }

    @Test func everythingSmallLeavesNothing() throws {
        let small = grid(side: 2, offset: .zero)
        let mesh = try Mesh(vertices: small.vertices, triangles: small.triangles)
        let result = MeshPieces.droppingSmallPieces(of: mesh, smallestFaces: 60)
        #expect(result.mesh.isEmpty)
        #expect(result.facesDropped == 8)
    }

    @Test func turnedOffWhenTheLimitIsOne() throws {
        let small = grid(side: 1, offset: .zero)
        let mesh = try Mesh(vertices: small.vertices, triangles: small.triangles)
        #expect(MeshPieces.droppingSmallPieces(of: mesh, smallestFaces: 1).mesh == mesh)
    }
}

struct SweepFusionProgressTests {
    @Test func fullMemoryIsPromptedWhenTrackingIsFine() {
        let progress = SweepProgress(faceCount: 10, fusedFrames: 40, fusionFull: true)
        #expect(progress.prompt == SweepProgress.fusionFullPrompt)
    }

    @Test func trackingProblemsComeFirst() {
        let progress = SweepProgress(tracking: .limited(.movingTooFast), fusionFull: true)
        #expect(progress.prompt == "Slow down.")
    }

    @Test func noPromptWhenAllIsWell() {
        #expect(SweepProgress(faceCount: 10, fusedFrames: 4).prompt == nil)
    }

    @Test func statsCountDepthPictures() {
        #expect(CaptureText.stats(SweepProgress(anchorCount: 2, faceCount: 10)) == "2 areas · 10 faces")
        #expect(
            CaptureText.stats(SweepProgress(anchorCount: 2, faceCount: 10, fusedFrames: 1))
                == "2 areas · 10 faces · 1 depth picture")
        #expect(
            CaptureText.stats(SweepProgress(anchorCount: 2, faceCount: 10, fusedFrames: 1_250))
                == "2 areas · 10 faces · 1,250 depth pictures")
    }
}
