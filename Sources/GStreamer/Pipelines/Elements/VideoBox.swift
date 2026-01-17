/// A pipeline element that adds borders or crops video frames.
///
/// VideoBox can add colored borders (positive values) or crop (negative values).
/// Unlike ``VideoCrop``, VideoBox can also add padding around the video.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func paddedPipeline() -> PartialPipeline<VideoFrame> {
///     VideoTestSource()
///     VideoBox(top: 20, bottom: 20, left: 20, right: 20, fill: .black)
/// }
/// ```
public struct VideoBox: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    /// Fill color for borders.
    public enum Fill: Int, Sendable {
        case black = 0
        case green = 1
        case blue = 2
        case red = 3
        case yellow = 4
        case white = 5
    }

    private let top: Int
    private let bottom: Int
    private let left: Int
    private let right: Int
    private let fill: Fill?
    private let alpha: Double?

    public var pipeline: String {
        var options = ["videobox"]
        if top != 0 { options.append("top=\(top)") }
        if bottom != 0 { options.append("bottom=\(bottom)") }
        if left != 0 { options.append("left=\(left)") }
        if right != 0 { options.append("right=\(right)") }
        if let fill { options.append("fill=\(fill.rawValue)") }
        if let alpha { options.append("alpha=\(alpha)") }
        return options.joined(separator: " ")
    }

    /// Create a VideoBox element.
    ///
    /// Positive values add borders, negative values crop.
    ///
    /// - Parameters:
    ///   - top: Pixels to add/remove from top (positive = add border, negative = crop).
    ///   - bottom: Pixels to add/remove from bottom.
    ///   - left: Pixels to add/remove from left.
    ///   - right: Pixels to add/remove from right.
    ///   - fill: Fill color for added borders.
    ///   - alpha: Alpha value for borders (0.0 to 1.0).
    public init(
        top: Int = 0,
        bottom: Int = 0,
        left: Int = 0,
        right: Int = 0,
        fill: Fill? = nil,
        alpha: Double? = nil
    ) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.fill = fill
        self.alpha = alpha
    }

    /// Add uniform padding on all sides.
    ///
    /// - Parameters:
    ///   - padding: Pixels to add on all sides.
    ///   - fill: Fill color for the padding.
    public static func padding(_ padding: Int, fill: Fill = .black) -> VideoBox {
        VideoBox(top: padding, bottom: padding, left: padding, right: padding, fill: fill)
    }

    /// Add letterboxing (horizontal bars) for aspect ratio adjustment.
    ///
    /// - Parameters:
    ///   - height: Pixels to add on top and bottom.
    ///   - fill: Fill color for the bars.
    public static func letterbox(_ height: Int, fill: Fill = .black) -> VideoBox {
        VideoBox(top: height, bottom: height, fill: fill)
    }

    /// Add pillarboxing (vertical bars) for aspect ratio adjustment.
    ///
    /// - Parameters:
    ///   - width: Pixels to add on left and right.
    ///   - fill: Fill color for the bars.
    public static func pillarbox(_ width: Int, fill: Fill = .black) -> VideoBox {
        VideoBox(left: width, right: width, fill: fill)
    }
}
