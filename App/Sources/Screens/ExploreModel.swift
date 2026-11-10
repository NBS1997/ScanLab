import CoreGraphics
import Foundation
import Observation
import ScanLabCore
import UIKit

/// The layers of the Explore screen (FR-2.1).
enum ExploreLayer: String, CaseIterable, Sendable {
    case camera = "Camera"
    case depth = "Depth"
    case confidence = "Confidence"
    case edges = "Edges"
}

/// What the Explore screen shows (mockups screen 6): the live layers, the distance at
/// the centre and the frame rate. Starts the sensor when the screen appears and stops
/// it when the screen goes away, because only one screen may hold the sensor.
@MainActor
@Observable
final class ExploreModel {
    /// How often the distance and frame-rate text change. Faster is unreadable, and
    /// would make the screen reader chatter.
    static let textRefreshInterval: TimeInterval = 0.25
    /// Edge detection arrives with Bolt 11 (U12).
    static let edgesUnavailableReason = "Coming in a later build"

    /// How long a new depth hint must hold before it is shown, so it does not flicker
    /// as the hand wobbles (and the log records only real changes).
    static let hintHoldSeconds: TimeInterval = 0.75

    let feed: any LiveCameraFeeding
    let confidenceColours = ConfidenceColourMap.standard

    var showCamera = true
    var showDepth = false
    var showConfidence = false
    /// Close-range colour mode (owner feedback 2026-11-11): the depth colours spread
    /// over a narrow band around the centre distance, so a 2 cm step stands out.
    var closeRange = false
    private(set) var band = CloseRangeBand()
    /// "Move closer", "Move back", or nil when the depth at the centre looks fine.
    private(set) var depthHint: String?

    private(set) var status: SensorStatus = .starting
    private(set) var depthImage: CGImage?
    private(set) var confidenceImage: CGImage?
    private(set) var centreMetres: Float?
    private(set) var framesPerSecond: Double?

    @ObservationIgnored private let log: any Logging
    @ObservationIgnored private var turn = QuarterTurn.clockwise
    @ObservationIgnored private var meter = FrameRateMeter()
    @ObservationIgnored private var lastTextRefresh = -TimeInterval.infinity
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var advice = SteadyValue(DepthAdvice.good, holdSeconds: ExploreModel.hintHoldSeconds)
    /// The last good centre distance, which helps the hint when the centre goes blank.
    @ObservationIgnored private var recentDistance: Float?

    init(environment: AppEnvironment) {
        feed = environment.sensorFeed
        log = environment.log
    }

    var centreText: String { ReadoutText.distance(metres: centreMetres) }
    var centreSpoken: String { ReadoutText.spokenDistance(metres: centreMetres) }
    var frameRateText: String { ReadoutText.frameRate(framesPerSecond) }
    var frameRateSpoken: String { ReadoutText.spokenFrameRate(framesPerSecond) }

    /// The colours in use: the close-range band when that mode is on and a reading has
    /// arrived, otherwise the standard 0.2–5 m map.
    var depthColours: DepthColourMap {
        guard closeRange, let map = band.colourMap else { return .standard }
        return map
    }

    /// True while close-range mode is on but no centre reading has arrived yet.
    var isWaitingForBand: Bool { closeRange && band.colourMap == nil }

    // MARK: - Sensor lifetime

    func start() {
        guard tasks.isEmpty else { return }
        status = .starting
        meter.reset()
        lastTextRefresh = -.infinity
        advice = SteadyValue(DepthAdvice.good, holdSeconds: Self.hintHoldSeconds)
        depthHint = nil
        log.info("ui", "Explore shown", ["layers": layerSummary])
        let streams = feed.start()
        // Two loops, one per stream. Both run on the main actor, as this model does,
        // so they can update what the screen shows directly.
        tasks.append(
            Task { [weak self] in
                for await status in streams.statuses {
                    self?.status = status
                }
            })
        tasks.append(
            Task { [weak self] in
                for await frame in streams.frames {
                    self?.handle(frame)
                }
            })
    }

    func stop() {
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        feed.stop()
        depthImage = nil
        confidenceImage = nil
        log.info("ui", "Explore left")
    }

    // MARK: - Close-range mode

    /// Turning close range on also turns the depth layer on, since the mode only
    /// changes the depth colours.
    func closeRangeChanged(isOn: Bool) {
        if isOn {
            band = CloseRangeBand(halfWidth: band.halfWidth)
            band.follow(centreMetres)
            showDepth = true
        }
        log.info(
            "ui", "Explore colour mode changed",
            [
                "mode": isOn ? "close range" : "standard",
                "band": CloseRangeBand.label(halfWidth: band.halfWidth),
                "centre": ReadoutText.distance(metres: band.centre),
            ])
    }

    func setBandHalfWidth(_ halfWidth: Float) {
        guard halfWidth != band.halfWidth else { return }
        band.setHalfWidth(halfWidth)
        log.info("ui", "Explore close-range band changed", ["band": CloseRangeBand.label(halfWidth: band.halfWidth)])
    }

    // MARK: - Layers

    func layerChanged(_ layer: ExploreLayer, isOn: Bool) {
        if !showDepth {
            depthImage = nil
        }
        if !showConfidence {
            confidenceImage = nil
        }
        log.info("ui", "Explore layer changed", ["layer": layer.rawValue, "on": isOn ? "yes" : "no"])
    }

    /// Records which way the phone is held, so the overlays turn with the picture.
    func interfaceOrientationChanged(_ orientation: UIInterfaceOrientation) {
        turn = Self.overlayTurn(for: orientation)
    }

    /// The depth grid arrives in the camera sensor's own orientation, which matches the
    /// phone held sideways with the top of the phone to the left (the interface
    /// orientation called "landscape right"). ARKit turns the camera picture for us;
    /// the overlays must be turned the same way: upright needs a quarter turn
    /// clockwise, the other sideways position a half turn.
    static func overlayTurn(for orientation: UIInterfaceOrientation) -> QuarterTurn {
        switch orientation {
        case .landscapeRight: .none
        case .landscapeLeft: .half
        case .portraitUpsideDown: .anticlockwise
        case .portrait, .unknown: .clockwise
        @unknown default: .clockwise
        }
    }

    private var layerSummary: String {
        var names: [String] = []
        if showCamera {
            names.append(ExploreLayer.camera.rawValue)
        }
        if showDepth {
            names.append(ExploreLayer.depth.rawValue)
        }
        if showConfidence {
            names.append(ExploreLayer.confidence.rawValue)
        }
        return names.isEmpty ? "none" : names.joined(separator: ", ")
    }

    // MARK: - Frames

    private func handle(_ frame: SensorFrame) {
        meter.record(frame.timestamp)
        if let depth = frame.depth {
            depthImage = showDepth ? depthPicture(for: depth) : nil
            confidenceImage = showConfidence ? confidencePicture(for: depth) : nil
        }
        guard frame.timestamp - lastTextRefresh >= Self.textRefreshInterval else { return }
        lastTextRefresh = frame.timestamp
        framesPerSecond = meter.framesPerSecond
        centreMetres = frame.depth.flatMap { CentreSampler.distance(in: $0) }
        if let centreMetres {
            recentDistance = centreMetres
        }
        if closeRange {
            band.follow(centreMetres)
        }
        if let depth = frame.depth {
            updateHint(for: depth, at: frame.timestamp)
        }
    }

    /// Asks Core's advisor about the square at the centre, and changes the hint only
    /// once the new advice has held for `hintHoldSeconds`.
    private func updateHint(for depth: DepthFrame, at timestamp: TimeInterval) {
        let input = DepthQualityInput.centre(of: depth, recentDistance: recentDistance)
        guard advice.update(PoorDepthAdvisor.advice(for: input), at: timestamp) else { return }
        depthHint = advice.shown.hint
        log.info(
            "ui", "Depth hint changed",
            ["hint": advice.shown.logName, "centre": ReadoutText.distance(metres: centreMetres)])
        // Spoken by VoiceOver when it is on; ignored otherwise.
        if let hint = depthHint {
            UIAccessibility.post(notification: .announcement, argument: hint)
        }
    }

    // The overlays are painted in the sensor's orientation, turned to match the
    // phone, then handed to SwiftUI as system images. At 256 × 192 this takes about a
    // millisecond, so it is done here rather than on another thread.
    private func depthPicture(for depth: DepthFrame) -> CGImage? {
        OverlayRenderer.depthImage(for: depth, using: depthColours).rotated(turn).makeCGImage()
    }

    private func confidencePicture(for depth: DepthFrame) -> CGImage? {
        OverlayRenderer.confidenceImage(for: depth, using: confidenceColours)?.rotated(turn).makeCGImage()
    }
}
