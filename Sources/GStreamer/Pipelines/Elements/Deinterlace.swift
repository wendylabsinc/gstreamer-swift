/// A pipeline element that deinterlaces video streams.
///
/// Use this element when processing interlaced video content (common in broadcast
/// and older video formats) to convert to progressive frames.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func deinterlacedPipeline() -> PartialPipeline<VideoFrame> {
///     URIDecodeSource.file(path: "/path/to/interlaced.ts")
///     Deinterlace()
/// }
/// ```
public struct Deinterlace: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    /// Deinterlacing mode.
    public enum Mode: Int, Sendable {
        /// Automatic detection based on caps/flags
        case auto = 0
        /// Force deinterlacing
        case interlaced = 1
        /// Disable deinterlacing (passthrough)
        case disabled = 2
    }

    /// Deinterlacing method.
    public enum Method: Int, Sendable {
        /// Automatic method selection
        case auto = 0
        /// Blend fields together
        case blend = 1
        /// Linear interpolation
        case linear = 2
        /// Linear blend
        case linearBlend = 3
        /// Scale from half-height
        case scalerBob = 4
        /// Weave fields together
        case weave = 5
        /// Weave top field first
        case weaveTFF = 6
        /// Weave bottom field first
        case weaveBFF = 7
    }

    /// Field layout detection.
    public enum Fields: Int, Sendable {
        /// Automatic detection
        case auto = 0
        /// Top field first
        case topFieldFirst = 1
        /// Bottom field first
        case bottomFieldFirst = 2
    }

    private let mode: Mode
    private let method: Method
    private let fields: Fields

    public var pipeline: String {
        var options = ["deinterlace"]
        options.append("mode=\(mode.rawValue)")
        options.append("method=\(method.rawValue)")
        options.append("fields=\(fields.rawValue)")
        return options.joined(separator: " ")
    }

    /// Create a Deinterlace element with automatic settings.
    public init() {
        self.mode = .auto
        self.method = .auto
        self.fields = .auto
    }

    /// Create a Deinterlace element with specific settings.
    ///
    /// - Parameters:
    ///   - mode: When to deinterlace.
    ///   - method: Which algorithm to use.
    ///   - fields: Field order assumption.
    public init(mode: Mode = .auto, method: Method = .auto, fields: Fields = .auto) {
        self.mode = mode
        self.method = method
        self.fields = fields
    }

    /// Force deinterlacing with linear blend method (good quality/performance balance).
    public static let linearBlend = Deinterlace(mode: .interlaced, method: .linearBlend)
}
