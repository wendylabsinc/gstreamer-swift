/// A pipeline element that filters based on capabilities.
///
/// Capsfilter restricts the media format flowing through a pipeline.
/// This is the generic version; prefer ``RawVideoFormat`` for typed video caps.
///
/// ## Example
///
/// ```swift
/// let caps = Capsfilter("video/x-raw,format=I420,width=1920,height=1080")
/// ```
public struct Capsfilter: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let caps: String

    public var pipeline: String {
        "capsfilter caps=\"\(caps)\""
    }

    /// Create a Capsfilter with a caps string.
    ///
    /// - Parameter caps: GStreamer caps string (e.g., "video/x-raw,format=NV12").
    public init(_ caps: String) {
        self.caps = caps
    }
}

/// A pipeline element that passes data through unchanged.
///
/// Identity is useful for debugging, adding probe points, or as a placeholder.
/// It preserves the frame layout type in typed pipelines automatically.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func debugPipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     TypedVideoTestSource<BGRA<1920, 1080>>()
///     Identity(silent: false)  // Layout inferred, will log each buffer
/// }
/// ```
public struct Identity: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    private let silent: Bool
    private let singleSegment: Bool
    private let dropProbability: Double?

    public var pipeline: String {
        var options = ["identity"]
        if !silent {
            options.append("silent=false")
        }
        if singleSegment {
            options.append("single-segment=true")
        }
        if let dropProbability {
            options.append("drop-probability=\(dropProbability)")
        }
        return options.joined(separator: " ")
    }

    /// Create an Identity element.
    ///
    /// - Parameters:
    ///   - silent: Whether to suppress debug output (default true).
    ///   - singleSegment: Whether to output a single segment (useful for muxing).
    ///   - dropProbability: Probability of dropping buffers (0.0 to 1.0, for testing).
    public init(
        silent: Bool = true,
        singleSegment: Bool = false,
        dropProbability: Double? = nil
    ) {
        self.silent = silent
        self.singleSegment = singleSegment
        self.dropProbability = dropProbability
    }

    /// Debug identity that logs all buffers.
    public static let debug = Identity(silent: false)
}

/// A pipeline element that controls data flow.
///
/// Valve can block or allow data flow, useful for implementing
/// pause/resume or conditional processing.
/// It preserves the frame layout type in typed pipelines automatically.
public struct Valve: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    private let drop: Bool

    public var pipeline: String {
        "valve drop=\(drop)"
    }

    /// Create a Valve element.
    ///
    /// - Parameter drop: Whether to drop all buffers (default false = pass through).
    public init(drop: Bool = false) {
        self.drop = drop
    }

    /// Valve that blocks all data.
    public static let closed = Valve(drop: true)

    /// Valve that passes all data.
    public static let open = Valve(drop: false)
}

/// A pipeline element that synchronizes streams.
///
/// InputSelector can switch between multiple input pads, useful for
/// implementing A/B switching or stream selection.
public struct InputSelector: VideoPipelineElement {
    private let syncStreams: Bool

    public var pipeline: String {
        var options = ["input-selector"]
        if syncStreams {
            options.append("sync-streams=true")
        }
        return options.joined(separator: " ")
    }

    /// Create an InputSelector.
    ///
    /// - Parameter syncStreams: Whether to synchronize streams during switching.
    public init(syncStreams: Bool = false) {
        self.syncStreams = syncStreams
    }
}

/// A pipeline element that provides a fakesink for testing.
///
/// Discards all incoming data, useful for benchmarking or testing.
/// Works with any frame layout in typed pipelines.
public struct FakeSink: TypedSinkable, VideoSink {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = Never

    public func _asTypedSink<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedSink<Layout> {
        AnyTypedSink<Layout>(pipeline: self.pipeline)
    }

    private let sync: Bool
    private let silent: Bool

    public var pipeline: String {
        var options = ["fakesink"]
        if !sync {
            options.append("sync=false")
        }
        if !silent {
            options.append("silent=false")
        }
        return options.joined(separator: " ")
    }

    /// Create a FakeSink.
    ///
    /// - Parameters:
    ///   - sync: Whether to synchronize to clock (default false for max throughput).
    ///   - silent: Whether to suppress debug output (default true).
    public init(sync: Bool = false, silent: Bool = true) {
        self.sync = sync
        self.silent = silent
    }
}
