import Foundation

/// Every tunable number for depth fusion (U14, ADR-029), kept together so they can be
/// tuned against the reference object. **All are first guesses.**
///
/// Distances are in metres.
public struct FusionSettings: Equatable, Sendable {
    /// The side of one cube in the grid. Smaller shows more detail but needs more memory
    /// and more readings to fill (DF-1).
    public var voxelSize = 0.004
    /// How far in front of and behind each measured point the cubes are updated (DF-1).
    /// It must be wider than the sensor's noise, or the noise tears holes in the surface.
    public var band = 0.016
    /// Readings nearer than this are ignored (DF-2).
    public var nearestDepth = 0.10
    /// Readings farther than this are ignored, so the room behind the subject is not
    /// fused (DF-2).
    public var farthestDepth = 1.0
    /// Use every reading (1) or every second one (2) and so on, to save time.
    public var pixelStep = 1
    /// How much a medium-confidence reading counts compared with a high one. Low
    /// confidence readings are ignored (DF-2).
    public var mediumConfidenceWeight = 0.35
    /// A cube's weight stops growing here, so later views can still correct it (DF-2).
    public var maximumWeight = 64.0
    /// A cube must be seen at least this much to be part of the surface (DF-3).
    public var minimumWeightToDraw = 1.5
    /// The memory cap, in blocks of 8 × 8 × 8 cubes (DF-6). Each block takes 5 KB, so
    /// the cap is about 60 MB.
    public var maximumBlocks = 12_000
    /// Loose pieces with fewer triangles than this are dropped as noise (DF-4).
    public var smallestPieceFaces = 60

    public init() {}

    public static let standard = FusionSettings()

    /// Inside a subject box (SB-7): memory goes to the subject alone, so the cubes can be
    /// finer. The band is narrower to match, but still wider than the sensor's noise.
    public static let boxed: FusionSettings = {
        var settings = FusionSettings()
        settings.voxelSize = 0.003
        settings.band = 0.012
        return settings
    }()

    /// For the diagnostics log (DF-10).
    public var logDetails: [String: String] {
        [
            "voxel mm": String(format: "%.1f", voxelSize * 1_000),
            "band mm": String(format: "%.1f", band * 1_000),
            "range m": String(format: "%.2f-%.2f", nearestDepth, farthestDepth),
            "pixel step": String(pixelStep),
            "max blocks": String(maximumBlocks),
        ]
    }
}
