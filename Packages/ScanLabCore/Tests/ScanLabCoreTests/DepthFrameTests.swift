import Foundation
import Testing

@testable import ScanLabCore

@Suite("Depth frame")
struct DepthFrameTests {
    @Test("a frame with matching sizes keeps its values")
    func validFrame() throws {
        let frame = try #require(
            DepthFrame(width: 2, height: 2, depths: [1, 2, 3, 4], confidence: [0, 1, 2, 2], timestamp: 5))
        #expect(frame.depth(column: 1, row: 1) == 4)
        #expect(frame.depth(column: 0, row: 1) == 3)
        #expect(frame.confidenceLevel(column: 1, row: 0) == .medium)
        #expect(frame.hasConfidence)
        #expect(frame.timestamp == 5)
    }

    @Test("sizes that do not agree are refused")
    func mismatchedSizes() {
        #expect(DepthFrame(width: 2, height: 2, depths: [1, 2, 3]) == nil)
        #expect(DepthFrame(width: 2, height: 2, depths: [1, 2, 3, 4], confidence: [1]) == nil)
        #expect(DepthFrame(width: 0, height: 2, depths: []) == nil)
        #expect(DepthFrame(width: -1, height: -1, depths: [1]) == nil)
    }

    @Test("pixels outside the frame, and missing confidence, give nil")
    func outsideAndMissing() throws {
        let frame = try #require(DepthFrame(width: 2, height: 1, depths: [1, 2]))
        #expect(frame.depth(column: 2, row: 0) == nil)
        #expect(frame.depth(column: 0, row: -1) == nil)
        #expect(frame.confidenceLevel(column: 0, row: 0) == nil)
        #expect(!frame.hasConfidence)
    }

    @Test("an unknown confidence value has no level")
    func unknownConfidence() throws {
        let frame = try #require(DepthFrame(width: 1, height: 1, depths: [1], confidence: [7]))
        #expect(frame.confidenceLevel(column: 0, row: 0) == nil)
    }

    @Test("only finite distances above zero are readings")
    func validity() {
        #expect(DepthFrame.isValid(1.5))
        #expect(!DepthFrame.isValid(0))
        #expect(!DepthFrame.isValid(-1))
        #expect(!DepthFrame.isValid(.nan))
        #expect(!DepthFrame.isValid(.infinity))
    }

    @Test("confidence levels are ordered and named")
    func confidenceLevels() {
        #expect(ConfidenceLevel.low < .medium)
        #expect(ConfidenceLevel.medium < .high)
        #expect(ConfidenceLevel.allCases.map(\.name) == ["Low", "Medium", "High"])
    }
}

@Suite("Sensor status")
struct SensorStatusTests {
    @Test("every status has the expected message")
    func messages() {
        #expect(SensorStatus.starting.message == "Starting camera")
        #expect(SensorStatus.running.message == nil)
        #expect(SensorStatus.stopped.message == "Camera stopped")
        #expect(SensorStatus.interrupted.message?.contains("paused") == true)
        #expect(SensorStatus.permissionDenied.message?.contains("Settings") == true)
        #expect(SensorStatus.unsupported(reason: "No LiDAR").message == "No LiDAR")
        #expect(SensorStatus.failed(reason: "boom").message == "The camera could not start: boom")
    }

    @Test("only problems the owner must act on block the view")
    func blocking() {
        #expect(SensorStatus.permissionDenied.blocksView)
        #expect(SensorStatus.unsupported(reason: "x").blocksView)
        #expect(SensorStatus.failed(reason: "x").blocksView)
        #expect(!SensorStatus.starting.blocksView)
        #expect(!SensorStatus.running.blocksView)
        #expect(!SensorStatus.interrupted.blocksView)
        #expect(!SensorStatus.stopped.blocksView)
    }

    @Test("streams and frames carry what they were given")
    func streams() async throws {
        let (frames, frameContinuation) = AsyncStream.makeStream(of: SensorFrame.self)
        let (statuses, statusContinuation) = AsyncStream.makeStream(of: SensorStatus.self)
        let streams = SensorStreams(frames: frames, statuses: statuses)
        let depth = try #require(DepthFrame(width: 1, height: 1, depths: [2]))
        frameContinuation.yield(SensorFrame(timestamp: 3, depth: depth))
        frameContinuation.finish()
        statusContinuation.yield(.running)
        statusContinuation.finish()
        var received: [SensorFrame] = []
        for await frame in streams.frames {
            received.append(frame)
        }
        var receivedStatuses: [SensorStatus] = []
        for await status in streams.statuses {
            receivedStatuses.append(status)
        }
        #expect(received == [SensorFrame(timestamp: 3, depth: depth)])
        #expect(receivedStatuses == [.running])
    }
}
