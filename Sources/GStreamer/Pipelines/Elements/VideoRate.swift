/// A pipeline element that adjusts the framerate of a video stream.
///
/// VideoRate can duplicate or drop frames to achieve a target framerate.
/// Use in combination with ``RawVideoFormat`` to specify the output framerate.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func normalizedPipeline() -> PartialPipeline<VideoFrame> {
///     URIDecodeSource.file(path: "/path/to/video.mp4")
///     VideoRate()
///     RawVideoFormat(width: 1920, height: 1080)  // Add framerate=30/1 for target fps
/// }
/// ```
public struct VideoRate: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let dropOnly: Bool
    private let skipToFirst: Bool

    public var pipeline: String {
        var options = ["videorate"]
        if dropOnly {
            options.append("drop-only=true")
        }
        if skipToFirst {
            options.append("skip-to-first=true")
        }
        return options.joined(separator: " ")
    }

    /// Create a VideoRate element.
    ///
    /// - Parameters:
    ///   - dropOnly: If true, only drop frames (never duplicate). Useful for reducing framerate.
    ///   - skipToFirst: If true, skip processing until the first frame arrives. Useful for live sources.
    public init(dropOnly: Bool = false, skipToFirst: Bool = false) {
        self.dropOnly = dropOnly
        self.skipToFirst = skipToFirst
    }
}
