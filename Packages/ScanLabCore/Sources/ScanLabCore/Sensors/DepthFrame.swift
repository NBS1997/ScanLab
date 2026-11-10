import Foundation

/// How sure the depth sensor is about one depth reading. The raw values match the
/// platform's own scale: 0 low, 1 medium, 2 high.
public enum ConfidenceLevel: UInt8, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    /// The plain-English name shown in the legend.
    public var name: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    public static func < (lhs: ConfidenceLevel, rhs: ConfidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One depth picture from the depth sensor, copied into plain arrays so Core can work
/// with it without knowing anything about the camera frameworks (ADR-003).
///
/// Pixels are stored row by row, top row first, in the sensor's own orientation (the
/// phone held sideways). On the iPhone the grid is 256 × 192 (platform verification V1).
public struct DepthFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Distance from the camera to the surface, in metres. NaN or zero means no reading.
    public let depths: [Float]
    /// One confidence value per pixel (0, 1 or 2). Empty when the sensor gave none.
    public let confidence: [UInt8]
    /// When the frame was captured, in seconds on the sensor's own clock.
    public let timestamp: TimeInterval

    /// Returns nil when the sizes do not agree, so a damaged frame never reaches the
    /// colour maps or the centre sampler.
    public init?(width: Int, height: Int, depths: [Float], confidence: [UInt8] = [], timestamp: TimeInterval = 0) {
        guard width > 0, height > 0, depths.count == width * height else { return nil }
        guard confidence.isEmpty || confidence.count == depths.count else { return nil }
        self.width = width
        self.height = height
        self.depths = depths
        self.confidence = confidence
        self.timestamp = timestamp
    }

    public var hasConfidence: Bool { !confidence.isEmpty }

    /// The depth at a pixel, or nil if the pixel is outside the frame.
    public func depth(column: Int, row: Int) -> Float? {
        guard (0..<width).contains(column), (0..<height).contains(row) else { return nil }
        return depths[row * width + column]
    }

    /// The confidence at a pixel, or nil if there is none or the pixel is outside.
    public func confidenceLevel(column: Int, row: Int) -> ConfidenceLevel? {
        guard hasConfidence, (0..<width).contains(column), (0..<height).contains(row) else { return nil }
        return ConfidenceLevel(rawValue: confidence[row * width + column])
    }

    /// True when a depth value is a usable reading: a finite distance above zero.
    public static func isValid(_ metres: Float) -> Bool {
        metres.isFinite && metres > 0
    }
}
