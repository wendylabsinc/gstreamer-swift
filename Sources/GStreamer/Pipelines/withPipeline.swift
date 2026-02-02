public func runPipeline(
    @VideoPipelineBuilder buildPipeline: @Sendable () -> PartialPipeline<Never>
) async throws {
    let pipeline = try Pipeline(buildPipeline().pipeline)
    try pipeline.play()
    defer { pipeline.stop() }
    for await state in pipeline.bus.messages() {
        switch state {
        case .eos:
            return
        case .error(message: let error, let debug):
            throw GStreamerError.busError(error, source: nil, debug: debug)
        case .stateChanged, .element, .warning,
             .buffering, .durationChanged, .latency, .tag, .qos,
             .streamStart, .clockLost, .newClock, .progress, .info:
            continue
        }
    }
}

/// Run a pipeline that yields video frames, processing each frame with the provided closure.
/// The frame type is automatically inferred from the pipeline's sink.
///
/// ## Example
///
/// ```swift
/// try await withPipeline {
///     VideoTestSource(numberOfBuffers: 100)
///     VideoAppSink()
/// } withEachFrame: { frame in
///     // `frame` is inferred as VideoFrame
///     print("Frame: \(frame.width)x\(frame.height)")
/// }
/// ```
@Sendable public func withPipeline<Frame: VideoFrameProtocol>(
    @VideoPipelineBuilder buildPipeline: @Sendable () -> PartialPipeline<Frame>,
    withEachFrame: @Sendable (Frame) async throws -> Void
) async throws {
    let partial = buildPipeline()
    let sinkname = "sink\(UInt8.random(in: 0...255))"
    // sync=false is critical for live sources like RTSP
    // drop=true and max-buffers=1 prevent backpressure
    // emit-signals=true enables the new-sample signal
    let pipelineDescription = partial.pipeline + """
     ! appsink name=\(sinkname) sync=false drop=true max-buffers=1 emit-signals=true
    """
    let pipeline = try Pipeline(pipelineDescription)
    let sink = try pipeline.appSink(named: sinkname)
    try pipeline.play()
    defer { pipeline.stop() }

    for try await frame in sink.frames() {
        try await withEachFrame(Frame(unsafeCast: frame))
    }
}