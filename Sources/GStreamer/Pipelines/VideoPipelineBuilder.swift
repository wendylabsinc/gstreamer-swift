@resultBuilder
public struct VideoPipelineBuilder: Sendable {
    /// Source step that provides each frame.
    public static func buildPartialBlock<Source: VideoPipelineSource>(
        first source: Source
    ) -> PartialPipeline<Source.VideoFrameOutput> {
        PartialPipeline(pipeline: source.pipeline)
    }

    /// Format step that transforms the frame type into a different format.
    public static func buildPartialBlock<
        Input: Sendable,
        Frame: VideoFrameProtocol
    >(
        accumulated: PartialPipeline<Input>,
        next: some VideoFormat<Frame>
    ) -> PartialPipeline<Frame> {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next.pipeline)
    }

    /// Convert step that transforms the frame type into a different format.
    public static func buildPartialBlock<
        Input: VideoFrameProtocol,
        Output: VideoFrameProtocol
    >(
        accumulated: PartialPipeline<Input>,
        next: some VideoPipelineConvert<Input, Output>
    ) -> PartialPipeline<Output> {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next.pipeline)
    }

    /// Sink that terminates the pipeline (e.g., OSXVideoSink)
    public static func buildPartialBlock<
        Input: VideoFrameProtocol,
        Sink: VideoSink<Input>
    >(
        accumulated: PartialPipeline<Input>,
        next: Sink
    ) -> PartialPipeline<Never> where Sink.VideoFrameOutput == Never {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next.pipeline)
    }

    // MARK: - Typed Element Builders

    /// Resolves a typed element builder in a typed pipeline context.
    /// The `Layout` is inferred from the accumulated pipeline type.
    public static func buildPartialBlock<Layout: PixelLayoutProtocol>(
        accumulated: PartialPipeline<_VideoFrame<Layout>>,
        next: some TypedConvertible
    ) -> PartialPipeline<_VideoFrame<Layout>> {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next._asTypedConvert(Layout.self).pipeline)
    }

    /// Resolves a typed sink builder in a typed pipeline context.
    public static func buildPartialBlock<Layout: PixelLayoutProtocol>(
        accumulated: PartialPipeline<_VideoFrame<Layout>>,
        next: some TypedSinkable
    ) -> PartialPipeline<Never> {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next._asTypedSink(Layout.self).pipeline)
    }

    // MARK: - Non-Generic Steps (Fallback)

    /// Overload for non-generic VideoPipelineConvert steps.
    @_disfavoredOverload
    public static func buildPartialBlock<
        Input: VideoFrameProtocol,
        Output: VideoFrameProtocol
    >(
        accumulated: PartialPipeline<Input>,
        next: some VideoPipelineConvert<VideoFrame, Output>
    ) -> PartialPipeline<Output> {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next.pipeline)
    }

    /// Sink that terminates the pipeline (non-generic fallback).
    @_disfavoredOverload
    public static func buildPartialBlock<
        Input: VideoFrameProtocol,
        Sink: VideoSink<VideoFrame>
    >(
        accumulated: PartialPipeline<Input>,
        next: Sink
    ) -> PartialPipeline<Never> where Sink.VideoFrameOutput == Never {
        PartialPipeline(pipeline: accumulated.pipeline + " ! " + next.pipeline)
    }
}

// MARK: - Core Protocols

public protocol VideoPipelineElement: Sendable {
    var pipeline: String { get }
}

public protocol VideoPipelineSource: VideoPipelineElement {
    associatedtype VideoFrameOutput: VideoFrameProtocol
}

public protocol VideoPipelineConvert<VideoFrameInput, VideoFrameOutput>: VideoPipelineElement {
    associatedtype VideoFrameInput: VideoFrameProtocol
    associatedtype VideoFrameOutput: VideoFrameProtocol
}

public protocol VideoFormat<VideoFrameOutput>: VideoPipelineElement {
    associatedtype VideoFrameOutput: VideoFrameProtocol
}

public protocol VideoSink<VideoFrameInput>: VideoPipelineElement {
    associatedtype VideoFrameInput: VideoFrameProtocol
    associatedtype VideoFrameOutput: Sendable
}

// MARK: - Typed Element Builder Protocols

/// Type-erased wrapper for strongly-typed pipeline converts.
///
/// This wrapper allows elements to be used in typed pipelines while
/// preserving the layout type information through the result builder.
public struct AnyTypedConvert<Layout: PixelLayoutProtocol>: VideoPipelineConvert {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = _VideoFrame<Layout>

    public let pipeline: String

    public init(pipeline: String) {
        self.pipeline = pipeline
    }
}

/// Type-erased wrapper for strongly-typed pipeline sinks.
public struct AnyTypedSink<Layout: PixelLayoutProtocol>: VideoSink {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = Never

    public let pipeline: String

    public init(pipeline: String) {
        self.pipeline = pipeline
    }
}

/// A type that can produce a strongly-typed `VideoPipelineConvert` element.
///
/// Elements conforming to this protocol can be used in typed pipelines
/// without explicit type parameters - the `Layout` is inferred from context.
///
/// Example:
/// ```swift
/// @VideoPipelineBuilder
/// func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     TypedVideoTestSource<BGRA<1920, 1080>>()
///     TextOverlay("Hello")  // Layout inferred as BGRA<1920, 1080>
///     Queue(maxBuffers: 5)  // Layout inferred as BGRA<1920, 1080>
/// }
/// ```
public protocol TypedConvertible: VideoPipelineElement {
    /// Creates the strongly-typed element for the given layout.
    func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout>
}

/// A type that can produce a strongly-typed `VideoSink` element.
public protocol TypedSinkable: VideoPipelineElement {
    /// Creates the strongly-typed sink for the given layout.
    func _asTypedSink<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedSink<Layout>
}
