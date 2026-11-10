import Foundation
import Testing

@testable import ScanLabCore

/// A stand-in for the camera: hands back whatever mesh (or error) the test sets.
@MainActor
final class FakeSweepCapture: SweepCapturing {
    var result: Result<Mesh, any Error> = .success(.empty)
    private(set) var startCount = 0
    private(set) var finishCount = 0
    private(set) var cancelCount = 0

    func start() -> SweepStreams {
        startCount += 1
        let (progress, progressContinuation) = AsyncStream.makeStream(of: SweepProgress.self)
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        progressContinuation.finish()
        statusContinuation.finish()
        return SweepStreams(progress: progress, statuses: statuses)
    }

    func finish() async throws -> Mesh {
        finishCount += 1
        return try result.get()
    }

    func cancel() {
        cancelCount += 1
    }
}

@MainActor
@Suite("Sweep capture service")
struct SweepCaptureServiceTests {
    let fake = FakeSweepCapture()
    let log = MemoryLog()
    let store = MemoryScanStore()

    private func makeService(availableBytes: Int64? = nil) -> SweepCaptureService {
        let library = ScanLibrary(store: store, log: log, availableBytes: { availableBytes })
        return SweepCaptureService(capture: fake, library: library, log: log)
    }

    /// A tall thin box in the platform's y-up world: 0.1 m wide, 0.6 m high, 0.2 m deep.
    private func upright() -> Mesh {
        TestMeshes.cube().transformed(
            by: Transform(xRow: Vec3(0.1, 0, 0), yRow: Vec3(0, 0.6, 0), zRow: Vec3(0, 0, 0.2)))
    }

    private func startCapturing(_ service: SweepCaptureService) {
        _ = service.start()
        service.statusChanged(.starting)
        service.statusChanged(.running)
    }

    @Test("Finish saves the scan z-up to the library as a sweep")
    func happyPath() async throws {
        let service = makeService()
        fake.result = .success(upright())
        startCapturing(service)
        #expect(service.phase == .capturing)
        service.progressChanged(SweepProgress(anchorCount: 3, faceCount: 12, elapsed: 4))

        let phase = await service.finish()

        guard case .saved(let id) = phase else {
            Issue.record("expected saved, got \(phase)")
            return
        }
        let library = ScanLibrary(store: store, log: log)
        let scan = try await library.scan(id)
        #expect(scan.method == .sweep)
        #expect(scan.faceCount == 12)
        // Height was along y; saved scans have it along z.
        let size = try #require(scan.size)
        #expect(abs(size.z - 0.6) < 1e-9)
        #expect(abs(size.y - 0.2) < 1e-9)
        let messages = await log.readAll().events.map(\.message)
        #expect(messages.contains("Capture started"))
        #expect(messages.contains("Capture saved"))
    }

    @Test("an empty capture saves nothing and says so")
    func nothingCaptured() async throws {
        let service = makeService()
        fake.result = .success(.empty)
        startCapturing(service)

        #expect(await service.finish() == .failed(.nothingCaptured))
        #expect(try store.scanIDs().isEmpty)
        let warnings = await log.readAll().events.filter { $0.level == .warning }
        #expect(warnings.contains { $0.message == "Capture not saved" })
    }

    @Test("a full phone saves nothing and reports no space")
    func noSpace() async throws {
        let service = makeService(availableBytes: 10)
        fake.result = .success(upright())
        startCapturing(service)

        #expect(await service.finish() == .failed(.noSpace))
        #expect(try store.scanIDs().isEmpty)
    }

    @Test("a failure while building is reported as an error")
    func buildFails() async {
        let service = makeService()
        fake.result = .failure(CocoaError(.featureUnsupported))
        startCapturing(service)

        guard case .failed(.buildFailed) = await service.finish() else {
            Issue.record("expected buildFailed")
            return
        }
        let errors = await log.readAll().events.filter { $0.level == .error }
        #expect(!errors.isEmpty)
    }

    @Test("Finish is ignored until capturing has begun")
    func finishTooEarly() async {
        let service = makeService()
        _ = service.start()
        #expect(await service.finish() == .preparing)
        #expect(fake.finishCount == 0)
    }

    @Test("a second start while running is refused")
    func doubleStart() {
        let service = makeService()
        #expect(service.start() != nil)
        #expect(service.start() == nil)
        #expect(fake.startCount == 1)
    }

    @Test("refused permission, no sensor and a failed session each end the capture")
    func sensorProblems() {
        let cases: [(SensorStatus, CaptureError)] = [
            (.permissionDenied, .permissionDenied),
            (.unsupported(reason: "No LiDAR"), .sensorUnavailable("No LiDAR")),
            (.failed(reason: "boom"), .sessionFailed("boom")),
        ]
        for (status, expected) in cases {
            let fake = FakeSweepCapture()
            let service = SweepCaptureService(
                capture: fake, library: ScanLibrary(store: MemoryScanStore(), log: log), log: log)
            _ = service.start()
            service.statusChanged(status)
            #expect(service.phase == .failed(expected))
            #expect(fake.cancelCount == 1)
        }
    }

    @Test("an interruption does not end the capture")
    func interruption() {
        let service = makeService()
        startCapturing(service)
        service.statusChanged(.interrupted)
        service.statusChanged(.running)
        #expect(service.phase == .capturing)
    }

    @Test("Cancel stops the camera and saves nothing")
    func cancel() throws {
        let service = makeService()
        startCapturing(service)
        service.cancel()
        #expect(service.phase == .cancelled)
        #expect(fake.cancelCount == 1)
        #expect(try store.scanIDs().isEmpty)
        // A second cancel does nothing more.
        service.cancel()
        #expect(fake.cancelCount == 1)
    }
}

@Suite("Capture text")
struct CaptureTextTests {
    @Test("elapsed time reads as minutes and seconds")
    func elapsed() {
        #expect(CaptureText.elapsed(42.9) == "00:42")
        #expect(CaptureText.elapsed(65) == "01:05")
        #expect(CaptureText.elapsed(3_725) == "1:02:05")
        #expect(CaptureText.elapsed(-3) == "00:00")
        #expect(CaptureText.elapsed(.nan) == "00:00")
    }

    @Test("elapsed time is spoken in words")
    func spoken() {
        #expect(CaptureText.spokenElapsed(1) == "1 second")
        #expect(CaptureText.spokenElapsed(42) == "42 seconds")
        #expect(CaptureText.spokenElapsed(60) == "1 minute")
        #expect(CaptureText.spokenElapsed(125) == "2 minutes 5 seconds")
    }

    @Test("stats count areas and faces")
    func stats() {
        #expect(CaptureText.stats(.zero) == "No surface yet")
        #expect(CaptureText.stats(SweepProgress(anchorCount: 1, faceCount: 1)) == "1 area · 1 face")
        #expect(CaptureText.stats(SweepProgress(anchorCount: 12, faceCount: 34_560)) == "12 areas · 34,560 faces")
    }

    @Test("tracking prompts appear only when tracking is not normal")
    func trackingPrompts() {
        #expect(SweepTracking.normal.prompt == nil)
        #expect(SweepTracking.notAvailable.prompt != nil)
        let limits: [TrackingLimit] = [.initialising, .movingTooFast, .tooLittleDetail, .relocalising, .other]
        let prompts = limits.compactMap { SweepTracking.limited($0).prompt }
        #expect(Set(prompts).count == limits.count)
        let names = (limits.map { SweepTracking.limited($0) } + [.normal, .notAvailable]).map(\.logName)
        #expect(Set(names).count == limits.count + 2)
    }
}
