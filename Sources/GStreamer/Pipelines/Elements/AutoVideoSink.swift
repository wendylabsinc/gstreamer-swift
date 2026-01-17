/// A pipeline sink that automatically selects the best video output for the platform.
///
/// AutoVideoSink will select the most suitable video sink based on the platform:
/// - macOS: osxvideosink or glimagesink
/// - Linux: waylandsink, ximagesink, or glimagesink
/// - Windows: d3dvideosink
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func displayPipeline() -> PartialPipeline<Never> {
///     VideoTestSource()
///     AutoVideoSink()
/// }
/// ```
public struct AutoVideoSink: VideoSink {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = Never

    private let sync: Bool

    public var pipeline: String {
        var options = ["autovideosink"]
        if !sync {
            options.append("sync=false")
        }
        return options.joined(separator: " ")
    }

    /// Create an AutoVideoSink.
    ///
    /// - Parameter sync: If true, synchronize to clock (default). Set to false for live sources.
    public init(sync: Bool = true) {
        self.sync = sync
    }

    /// Create an AutoVideoSink configured for live sources (no sync).
    public static let live = AutoVideoSink(sync: false)
}

/// A pipeline sink that discards all video frames (useful for testing/benchmarking).
public struct FakeVideoSink: VideoSink {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = Never

    private let sync: Bool

    public var pipeline: String {
        var options = ["fakesink"]
        if !sync {
            options.append("sync=false")
        }
        return options.joined(separator: " ")
    }

    /// Create a FakeVideoSink.
    ///
    /// - Parameter sync: If true, synchronize to clock. Set to false for maximum throughput.
    public init(sync: Bool = false) {
        self.sync = sync
    }
}
