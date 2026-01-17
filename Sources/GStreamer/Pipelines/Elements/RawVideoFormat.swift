/// A pipeline element that applies raw video format constraints (caps filter).
///
/// Use this element in a pipeline to specify the exact video format you expect.
/// The generic type encodes the pixel format and dimensions at compile time.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func myPipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     VideoTestSource()
///     VideoConvert()
///     RawVideoFormat(layout: BGRA<1920, 1080>.self, framerate: "30/1")
/// }
/// ```
public struct RawVideoFormat<VideoFrameOutput: VideoFrameProtocol>: VideoFormat {
    public let pipeline: String

    /// Create a raw video format filter with just dimensions.
    ///
    /// - Parameters:
    ///   - width: The video width in pixels.
    ///   - height: The video height in pixels.
    public init(
        width: Int,
        height: Int
    ) where VideoFrameOutput == VideoFrame {
        self.pipeline = CapsBuilder.video()
            .size(width: width, height: height)
            .build()
    }

    /// Create a raw video format filter with a typed pixel layout.
    ///
    /// This initializer uses value generics to encode the format at the type level,
    /// ensuring type safety throughout the pipeline.
    ///
    /// - Parameters:
    ///   - layout: The pixel layout type (e.g., `BGRA<1920, 1080>.self`).
    ///   - framerate: Optional framerate as a fraction string (e.g., "30/1", "60/1").
    public init<PixelLayout: PixelLayoutProtocol>(
        layout: PixelLayout.Type,
        framerate: String? = nil
    ) where VideoFrameOutput == _VideoFrame<PixelLayout> {
        var builder = CapsBuilder(mediaType: "video/\(RawVideoFrameFormat<PixelLayout>.name)")

        // Add format options from the pixel layout
        for option in RawVideoFrameFormat<PixelLayout>.options + PixelLayout.options {
            let parts = option.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                builder = builder.property(String(parts[0]), String(parts[1]))
            }
        }

        if let framerate {
            builder = builder.property("framerate", framerate)
        }

        self.pipeline = builder.build()
    }
}