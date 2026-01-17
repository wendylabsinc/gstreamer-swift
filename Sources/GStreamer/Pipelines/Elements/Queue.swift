/// Queue leaky behavior when full.
public enum QueueLeaky: Int, Sendable {
    /// Not leaky - block when full
    case none = 0
    /// Drop oldest buffers when full
    case upstream = 1
    /// Drop newest buffers when full
    case downstream = 2
}

/// A pipeline element that buffers data between elements.
///
/// Queue decouples the data flow between elements, allowing each to run at its own pace.
/// This is useful for:
/// - Preventing upstream elements from blocking
/// - Adding threading boundaries
/// - Handling bursty data
///
/// Queue preserves the frame layout type in typed pipelines automatically.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func bufferedPipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     TypedVideoTestSource<BGRA<1920, 1080>>()
///     Queue(maxBuffers: 5)  // Layout inferred
///     VideoConvert()
/// }
/// ```
public struct Queue: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    private let maxBuffers: UInt?
    private let maxBytes: UInt?
    private let maxTime: UInt64?
    private let leaky: QueueLeaky?

    public var pipeline: String {
        var options = ["queue"]
        if let maxBuffers {
            options.append("max-size-buffers=\(maxBuffers)")
        }
        if let maxBytes {
            options.append("max-size-bytes=\(maxBytes)")
        }
        if let maxTime {
            options.append("max-size-time=\(maxTime)")
        }
        if let leaky {
            options.append("leaky=\(leaky.rawValue)")
        }
        return options.joined(separator: " ")
    }

    /// Create a Queue element with default settings.
    public init() {
        self.maxBuffers = nil
        self.maxBytes = nil
        self.maxTime = nil
        self.leaky = nil
    }

    /// Create a Queue element with specified limits.
    ///
    /// - Parameters:
    ///   - maxBuffers: Maximum number of buffers to queue.
    ///   - maxBytes: Maximum bytes to queue.
    ///   - maxTime: Maximum time to queue in nanoseconds.
    ///   - leaky: Behavior when queue is full.
    public init(
        maxBuffers: UInt? = nil,
        maxBytes: UInt? = nil,
        maxTime: UInt64? = nil,
        leaky: QueueLeaky? = nil
    ) {
        self.maxBuffers = maxBuffers
        self.maxBytes = maxBytes
        self.maxTime = maxTime
        self.leaky = leaky
    }

    /// Create a leaky queue that drops old buffers when full.
    ///
    /// Useful for live sources where you want to keep the most recent data.
    public static func leaky(maxBuffers: UInt = 1) -> Queue {
        Queue(maxBuffers: maxBuffers, leaky: .upstream)
    }
}
