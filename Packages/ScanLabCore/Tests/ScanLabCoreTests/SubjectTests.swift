import Foundation
import Testing

@testable import ScanLabCore

/// A block standing on a table, seen from above and to one side, for the subject tests.
enum TableScene {
    static let block = Box(minimum: Vec3(-0.05, 0, -0.04), maximum: Vec3(0.05, 0.06, 0.04))
    static let camera = SyntheticDepth.camera(at: Vec3(0, 0.30, 0.30), lookingAt: Vec3(0, 0.02, 0))

    /// The depth picture, and which pixels see the block (a perfect subject outline).
    static func picture(camera: Transform = camera) -> (frame: FusionFrame, blockPixels: [Bool]) {
        let count = SyntheticDepth.width * SyntheticDepth.height
        var depths = [Float](repeating: .nan, count: count)
        var onBlock = [Bool](repeating: false, count: count)
        for row in 0..<SyntheticDepth.height {
            for column in 0..<SyntheticDepth.width {
                let direction = SyntheticDepth.ray(column: column, row: row, camera: camera)
                let table = direction.y < 0 ? -camera.translation.y / direction.y : Double.infinity
                let hit = entry(into: block, from: camera.translation, along: direction) ?? .infinity
                let nearest = min(table, hit)
                guard nearest.isFinite, nearest > 0 else { continue }
                depths[row * SyntheticDepth.width + column] = Float(nearest)
                onBlock[row * SyntheticDepth.width + column] = hit <= table
            }
        }
        return (SyntheticDepth.frame(depths: depths, camera: camera, confidence: 2), onBlock)
    }

    /// Where a line first enters a box ("slab" method: the overlap of the three ranges of
    /// distance over which the line is between each pair of opposite faces).
    static func entry(into box: Box, from origin: Vec3, along direction: Vec3) -> Double? {
        var near = -Double.infinity
        var far = Double.infinity
        for axis in 0..<3 {
            let start = [origin.x, origin.y, origin.z][axis]
            let step = [direction.x, direction.y, direction.z][axis]
            let low = [box.minimum.x, box.minimum.y, box.minimum.z][axis]
            let high = [box.maximum.x, box.maximum.y, box.maximum.z][axis]
            if abs(step) < 1e-12 {
                guard start >= low, start <= high else { return nil }
                continue
            }
            let first = (low - start) / step
            let second = (high - start) / step
            near = max(near, min(first, second))
            far = min(far, max(first, second))
        }
        return near <= far && near > 0 ? near : nil
    }

    /// The pixel a world point lands on.
    static func pixel(of point: Vec3, in frame: FusionFrame) -> (column: Double, row: Double) {
        let local = frame.worldToCamera(point)
        let depth = -local.z
        return (
            frame.intrinsics.focalX * local.x / depth + frame.intrinsics.centreX,
            -frame.intrinsics.focalY * local.y / depth + frame.intrinsics.centreY
        )
    }

    static func mask(_ pixels: [Bool]) -> SubjectMask? {
        SubjectMask(width: SyntheticDepth.width, height: SyntheticDepth.height, inside: pixels)
    }
}

struct SubjectFinderTests {
    let scene = TableScene.picture()
    var topOfBlock: (column: Double, row: Double) { TableScene.pixel(of: Vec3(0, 0.06, 0), in: scene.frame) }

    @Test func outlineAndDepthBoxTheBlockAndCutTheTable() throws {
        let result = SubjectFinder.find(
            in: scene.frame, tappedColumn: topOfBlock.column, tappedRow: topOfBlock.row,
            mask: TableScene.mask(scene.blockPixels))
        let box = try result.get()
        #expect(box.usedMask)
        let floor = try #require(box.floorHeight)
        #expect(abs(floor) < 0.003)
        #expect(abs(box.bounds.minimum.y - (floor + 0.002)) < 1e-9)
        // The box holds the block's seen faces, with its margins, and not much more.
        #expect(box.bounds.minimum.x < -0.05 && box.bounds.maximum.x > 0.05)
        #expect(box.bounds.maximum.y > 0.06)
        #expect(box.bounds.size.x < 0.15)
        #expect(box.bounds.size.y < 0.12)
    }

    @Test func withoutAnOutlineTheNearbyPointsAboveTheTableAreUsed() throws {
        let result = SubjectFinder.find(
            in: scene.frame, tappedColumn: topOfBlock.column, tappedRow: topOfBlock.row, mask: nil)
        let box = try result.get()
        #expect(!box.usedMask)
        #expect(box.floorHeight != nil)
        #expect(box.bounds.minimum.x < -0.05 && box.bounds.maximum.x > 0.05)
        #expect(box.bounds.size.x < 0.15)
    }

    @Test func anOutlineThatMissesEveryReadingFallsBackToDepth() throws {
        let empty = [Bool](repeating: false, count: scene.blockPixels.count)
        let result = SubjectFinder.find(
            in: scene.frame, tappedColumn: topOfBlock.column, tappedRow: topOfBlock.row,
            mask: TableScene.mask(empty))
        #expect(try !result.get().usedMask)
    }

    @Test func tappingTheTableIsRefused() {
        let table = TableScene.pixel(of: Vec3(0.07, 0, 0.07), in: scene.frame)
        let result = SubjectFinder.find(in: scene.frame, tappedColumn: table.column, tappedRow: table.row, mask: nil)
        #expect(result == .failure(.tappedTheSurface))
    }

    @Test func tappingWhereThereIsNoDepthIsRefused() {
        let blank = SyntheticDepth.wall(depth: .nan)
        let result = SubjectFinder.find(in: blank, tappedColumn: 32, tappedRow: 24, mask: nil)
        #expect(result == .failure(.noDepthThere))
    }

    @Test func aTinyOutlineIsNotEnough() {
        var few = [Bool](repeating: false, count: scene.blockPixels.count)
        let centre = Int(topOfBlock.row) * SyntheticDepth.width + Int(topOfBlock.column)
        few[centre] = true
        few[centre + 1] = true
        let result = SubjectFinder.find(
            in: scene.frame, tappedColumn: topOfBlock.column, tappedRow: topOfBlock.row, mask: TableScene.mask(few))
        #expect(result == .failure(.notEnoughPoints))
    }

    @Test func failuresHaveWordsAndLogNames() {
        for error in [SubjectPickError.noDepthThere, .tappedTheSurface, .notEnoughPoints, .notReady] {
            #expect(!error.message.isEmpty)
            #expect(!error.logName.isEmpty)
        }
    }
}

struct SubjectBoxTests {
    let box = SubjectBox(
        bounds: Box(minimum: Vec3(0, 0.002, 0), maximum: Vec3(0.1, 0.08, 0.2)), floorHeight: 0, usedMask: true,
        pointCount: 300)

    @Test func biggerKeepsTheFloor() {
        let bigger = box.scaled(by: 1.1)
        #expect(abs(bigger.bounds.minimum.y - 0.002) < 1e-12)
        #expect(abs(bigger.bounds.size.x - 0.11) < 1e-12)
        #expect(abs(bigger.bounds.centre.x - 0.05) < 1e-12)
    }

    @Test func sidesStayWithinLimits() {
        let tiny = box.scaled(by: 0.01)
        #expect(abs(tiny.bounds.size.x - 0.04) < 1e-12)
        let huge = box.scaled(by: 100)
        #expect(abs(huge.bounds.size.z - 1.5) < 1e-12)
    }

    @Test func withoutAFloorItGrowsAboutTheCentre() {
        var floating = box
        floating.floorHeight = nil
        let bigger = floating.scaled(by: 2)
        #expect(abs(bigger.bounds.centre.y - box.bounds.centre.y) < 1e-12)
    }

    @Test func logDetailsGiveSizeInMillimetres() {
        #expect(box.logDetails["size mm"] == "100 x 78 x 200")
        #expect(box.logDetails["floor"] == "found")
        #expect(box.logDetails["mask"] == "yes")
    }

    @Test func maskChecksItsSizeAndBounds() throws {
        #expect(SubjectMask(width: 2, height: 2, inside: [true]) == nil)
        let mask = try #require(SubjectMask(width: 2, height: 1, inside: [false, true]))
        #expect(mask.contains(across: 0.75, down: 0.5))
        #expect(!mask.contains(across: 0.25, down: 0.5))
        #expect(!mask.contains(across: 1.0, down: 0.5))
        #expect(mask.share == 0.5)
    }
}

struct SubjectChoiceTests {
    let box = SubjectBox(bounds: Box(minimum: .zero, maximum: Vec3(0.1, 0.1, 0.1)))

    @Test func tapFindLockScan() {
        var choice = SubjectChoice()
        #expect(choice.instruction == "Tap the part you want to scan.")
        let step1 = choice.tapped()
        #expect(step1)
        #expect(choice.stage == .finding)
        let step2 = choice.found(.success(box))
        #expect(step2)
        #expect(choice.box == box)
        #expect(!choice.isScanning)
        let step3 = choice.resize(by: 1.1)
        #expect(step3)
        let step4 = choice.lock()
        #expect(step4)
        #expect(choice.isScanning)
        #expect(choice.instruction == nil)
        let step5 = choice.tapped()
        #expect(!step5)
        let step6 = choice.chooseWholeScene()
        #expect(!step6)
    }

    @Test func aFailedTapSaysWhyAndWaitsForAnother() {
        var choice = SubjectChoice()
        choice.tapped()
        choice.found(.failure(.tappedTheSurface))
        #expect(choice.stage == .choosing)
        #expect(choice.instruction == SubjectPickError.tappedTheSurface.message)
        choice.tapped()
        #expect(choice.lastFailure == nil)
    }

    @Test func outOfOrderStepsAreRefused() {
        var choice = SubjectChoice()
        let step7 = choice.found(.success(box))
        #expect(!step7)
        let step8 = choice.lock()
        #expect(!step8)
        let step9 = choice.resize(by: 2)
        #expect(!step9)
        choice.tapped()
        let step10 = choice.tapped()
        #expect(!step10)
        let step11 = choice.chooseWholeScene()
        #expect(!step11)
    }

    @Test func scanEverythingSkipsTheBox() {
        var choice = SubjectChoice()
        let step12 = choice.chooseWholeScene()
        #expect(step12)
        #expect(choice.isScanning)
        #expect(choice.box == nil)
        let step13 = choice.tapped()
        #expect(!step13)
    }

    @Test func anotherTapReplacesAProposedBox() {
        var choice = SubjectChoice()
        choice.tapped()
        choice.found(.success(box))
        let step14 = choice.tapped()
        #expect(step14)
        #expect(choice.stage == .finding)
    }
}

struct CoverageDomeTests {
    let centre = Vec3(0, 0.03, 0)

    @Test func directionsFollowHeightAndAngle() {
        let dome = CoverageDome(centre: centre)
        // Level with the box on +x: side ring, first step.
        #expect(dome.direction(of: centre + Vec3(0.4, 0, 0)) == 0)
        // Above and towards +z: raised ring (about 37°), step 2 (90°).
        #expect(dome.direction(of: centre + Vec3(0, 0.3, 0.4)) == 8 + 2)
        // Straight-ish down from above.
        #expect(dome.direction(of: centre + Vec3(0.05, 0.4, 0)) == 16)
        // Below the box, too far, or at the centre: nothing.
        #expect(dome.direction(of: centre + Vec3(0.4, -0.2, 0)) == nil)
        #expect(dome.direction(of: centre + Vec3(2, 0, 0)) == nil)
        #expect(dome.direction(of: centre) == nil)
    }

    @Test func picturesCountOnlyWhenTheBoxIsInView() {
        var dome = CoverageDome(centre: centre)
        let looking = SyntheticDepth.camera(at: centre + Vec3(0.4, 0.05, 0), lookingAt: centre)
        let away = SyntheticDepth.camera(at: centre + Vec3(0.4, 0.05, 0), lookingAt: centre + Vec3(1, 0, 0))
        let seen = dome.record(SyntheticDepth.wall(depth: 0.4, camera: looking))
        let unseen = dome.record(SyntheticDepth.wall(depth: 0.4, camera: away))
        #expect(seen == 0)
        #expect(unseen == nil)
        #expect(dome.counts[0] == 1)
    }

    @Test func aPatchIsCoveredAfterThreePictures() {
        var dome = CoverageDome(centre: centre)
        let camera = SyntheticDepth.camera(at: centre + Vec3(0.4, 0.05, 0), lookingAt: centre)
        for _ in 0..<2 {
            dome.record(SyntheticDepth.wall(depth: 0.4, camera: camera))
        }
        #expect(dome.summary(cameraAt: nil).coveredCount == 0)
        dome.record(SyntheticDepth.wall(depth: 0.4, camera: camera))
        let summary = dome.summary(cameraAt: camera.translation)
        #expect(summary.coveredCount == 1)
        #expect(summary.current == 0)
        #expect(summary.spoken == "1 of 24 directions covered")
    }

    @Test func stepsToYourLeftGoTowardsLargerAngles() {
        // Standing on +x facing the box (towards −x), your left hand points to +z: the
        // right-hand direction is "facing × up" = (−1, 0, 0) × (0, 1, 0) = (0, 0, −1).
        // So the uncovered patch towards +z (step 1) is "to your left".
        var covered = [Bool](repeating: true, count: 24)
        covered[1] = false
        let dome = CoverageDome(centre: centre)
        #expect(dome.prompt(covered: covered, current: 0) == "Go round to your left.")
        covered[1] = true
        covered[7] = false
        #expect(dome.prompt(covered: covered, current: 0) == "Go round to your right.")
    }

    @Test func heightComesBeforeGoingRound() {
        var covered = [Bool](repeating: true, count: 24)
        covered[8 + 4] = false
        let dome = CoverageDome(centre: centre)
        #expect(dome.prompt(covered: covered, current: 0) == "Raise the phone and look down on it.")
        #expect(dome.prompt(covered: covered, current: 20) == "Lower the phone to look at its side.")
        covered[12] = true
        covered[0] = false
        #expect(dome.prompt(covered: covered, current: 0) == "Hold here a moment.")
    }

    @Test func completeAndLostPrompts() {
        let dome = CoverageDome(centre: centre)
        let all = [Bool](repeating: true, count: 24)
        #expect(dome.prompt(covered: all, current: nil) == "All round covered. Tap Finish when ready.")
        #expect(CoverageSummary(covered: all, current: nil, prompt: nil).isComplete)
        let none = [Bool](repeating: false, count: 24)
        #expect(dome.prompt(covered: none, current: nil) == "Point the phone at the box.")
        #expect(CoverageSummary(covered: [], current: nil, prompt: nil).fraction == 0)
    }

    @Test func stepsBetweenWrapRound() {
        #expect(CoverageDome.signedSteps(from: 7, to: 0) == 1)
        #expect(CoverageDome.signedSteps(from: 0, to: 7) == -1)
        #expect(CoverageDome.stepsBetween(1, 5) == 4)
    }
}

struct RegionFusionTests {
    @Test func onlyCubesInsideTheBoxAreFused() {
        let region = Box(minimum: Vec3(-0.03, -0.03, -0.35), maximum: Vec3(0.03, 0.03, -0.25))
        let fusion = DepthFusion(settings: .boxed, region: region)
        for _ in 0..<3 {
            fusion.integrate(SyntheticDepth.wall(depth: 0.3))
        }
        let mesh = fusion.makeMesh().mesh
        #expect(!mesh.isEmpty)
        for vertex in mesh.vertices {
            #expect(region.contains(vertex, tolerance: 0.003))
        }
        let unboxed = DepthFusion(settings: .boxed)
        for _ in 0..<3 {
            unboxed.integrate(SyntheticDepth.wall(depth: 0.3))
        }
        #expect(unboxed.makeMesh().mesh.faceCount > mesh.faceCount)
    }

    @Test func readingsOutsideTheBoxAreSkipped() {
        let region = Box(minimum: Vec3(1, 1, 1), maximum: Vec3(1.1, 1.1, 1.1))
        let fusion = DepthFusion(region: region)
        fusion.integrate(SyntheticDepth.wall(depth: 0.3))
        #expect(fusion.stats.blocks == 0)
    }

    @Test func boxedSettingsAreFiner() {
        #expect(FusionSettings.boxed.voxelSize == 0.003)
        #expect(FusionSettings.boxed.band == 0.012)
        #expect(FusionSettings.boxed.voxelSize < FusionSettings.standard.voxelSize)
    }
}

struct CoveragePromptOrderTests {
    let coverage = CoverageSummary(covered: [false], current: 0, prompt: "Go round to your left.")

    @Test func coverageSpeaksWhenNothingMoreUrgentDoes() {
        #expect(SweepProgress(coverage: coverage).prompt == "Go round to your left.")
        #expect(SweepProgress(fusionFull: true, coverage: coverage).prompt == SweepProgress.fusionFullPrompt)
        #expect(SweepProgress(tracking: .limited(.movingTooFast), coverage: coverage).prompt == "Slow down.")
    }
}
