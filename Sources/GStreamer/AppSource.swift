import CGStreamer
import CGStreamerApp
import CGStreamerShim

/// A wrapper for GStreamer's appsrc element for pushing data into a pipeline.
///
/// AppSource allows your application to inject buffers into a GStreamer pipeline.
/// This is essential for streaming processed frames, encoding video, or feeding
/// data from custom sources.
///
/// ## Overview
///
/// Use AppSource to push video frames, audio samples, or raw data into a pipeline.
/// Common use cases include:
/// - Streaming processed frames to a network
/// - Encoding frames to video files
/// - Feeding ML-generated content into a pipeline
///
/// ## Topics
///
/// ### Creating an AppSource
///
/// - ``init(pipeline:name:)``
///
/// ### Configuring the Source
///
/// - ``setCaps(_:)``
/// - ``setLive(_:)``
/// - ``setMaxBytes(_:)``
/// - ``StreamType``
///
/// ### Pushing Data
///
/// - ``push(data:pts:duration:)``
/// - ``pushVideoFrame(data:width:height:format:pts:duration:)``
/// - ``endOfStream()``
///
/// ## Example
///
/// ```swift
/// // Create a pipeline that encodes frames to H.264
/// let pipeline = try Pipeline("""
///     appsrc name=src ! \
///     videoconvert ! \
///     x264enc tune=zerolatency ! \
///     mp4mux ! \
///     filesink location=output.mp4
///     """)
///
/// let src = try AppSource(pipeline: pipeline, name: "src")
///
/// // Configure for video
/// src.setCaps("video/x-raw,format=BGRA,width=640,height=480,framerate=30/1")
/// src.setLive(true)
///
/// try pipeline.play()
///
/// // Push frames
/// var pts: UInt64 = 0
/// let frameDuration: UInt64 = 33_333_333  // ~30fps in nanoseconds
///
/// for frameData in generateFrames() {
///     try src.push(data: frameData, pts: pts, duration: frameDuration)
///     pts += frameDuration
/// }
///
/// src.endOfStream()
/// ```
///
/// ## Webcam Processing Pipeline
///
/// ```swift
/// // Capture, process, and re-encode
/// let capturePipeline = try Pipeline("""
///     v4l2src ! videoconvert ! video/x-raw,format=BGRA ! appsink name=sink
///     """)
/// let encodePipeline = try Pipeline("""
///     appsrc name=src ! videoconvert ! x264enc ! appsink name=out
///     """)
///
/// let sink = try capturePipeline.appSink(named: "sink")
/// let src = try AppSource(pipeline: encodePipeline, name: "src")
///
/// src.setCaps("video/x-raw,format=BGRA,width=640,height=480")
///
/// try capturePipeline.play()
/// try encodePipeline.play()
///
/// for await frame in sink.frames() {
///     // Process frame (ML inference, filters, etc.)
///     try frame.withMappedBytes { span in
///         span.withUnsafeBytes { buffer in
///             let processed = processPixels(buffer)
///             try src.push(data: processed, pts: frame.pts, duration: frame.duration)
///         }
///     }
/// }
/// ```
public final class AppSource: @unchecked Sendable {
    /// Stream type for the source.
    public enum StreamType: Sendable {
        /// A stream of buffers (most common).
        case stream
        /// A seekable stream.
        case seekable
        /// Random access (file-like).
        case randomAccess
    }

    /// The underlying element.
    private let element: Element

    /// The GstAppSrc pointer (cast from GstElement).
    private var appSrc: UnsafeMutablePointer<GstAppSrc> {
        UnsafeMutableRawPointer(element.element).assumingMemoryBound(to: GstAppSrc.self)
    }

    /// Create an AppSource from a pipeline by element name.
    ///
    /// The element must be an `appsrc` element in the pipeline.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline containing the appsrc.
    ///   - name: The name of the appsrc element (from `name=...` in pipeline).
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if no element with that name exists.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("appsrc name=src ! autovideosink")
    /// let src = try AppSource(pipeline: pipeline, name: "src")
    /// ```
    public init(pipeline: Pipeline, name: String) throws {
        guard let element = pipeline.element(named: name) else {
            throw GStreamerError.elementNotFound(name)
        }
        self.element = element
    }

    /// Set the capabilities (format) for this source.
    ///
    /// This tells downstream elements what format to expect.
    ///
    /// - Parameter capsString: A caps string describing the format.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Video caps
    /// src.setCaps("video/x-raw,format=BGRA,width=1920,height=1080,framerate=30/1")
    ///
    /// // Audio caps
    /// src.setCaps("audio/x-raw,format=S16LE,rate=44100,channels=2,layout=interleaved")
    /// ```
    public func setCaps(_ capsString: String) {
        guard let caps = swift_gst_caps_from_string(capsString) else { return }
        swift_gst_app_src_set_caps(appSrc, caps)
        swift_gst_caps_unref(caps)
    }

    /// Set whether this source behaves as a live source.
    ///
    /// Live sources (webcams, microphones) produce data in real-time.
    /// This affects buffering and synchronization behavior.
    ///
    /// - Parameter isLive: `true` for live sources, `false` for file-like sources.
    public func setLive(_ isLive: Bool) {
        swift_gst_app_src_set_is_live(appSrc, isLive ? 1 : 0)
    }

    /// Set the maximum bytes to queue internally.
    ///
    /// When the internal queue reaches this size, ``push(data:pts:duration:)``
    /// will block until space is available.
    ///
    /// - Parameter maxBytes: Maximum bytes to buffer (0 = unlimited).
    public func setMaxBytes(_ maxBytes: UInt64) {
        swift_gst_app_src_set_max_bytes(appSrc, maxBytes)
    }

    /// Set the stream type.
    ///
    /// - Parameter type: The type of stream this source produces.
    public func setStreamType(_ type: StreamType) {
        let gstType: GstAppStreamType
        switch type {
        case .stream: gstType = GST_APP_STREAM_TYPE_STREAM
        case .seekable: gstType = GST_APP_STREAM_TYPE_SEEKABLE
        case .randomAccess: gstType = GST_APP_STREAM_TYPE_RANDOM_ACCESS
        }
        swift_gst_app_src_set_stream_type(appSrc, gstType)
    }

    /// Push raw data into the pipeline.
    ///
    /// The data is copied into a GStreamer buffer and pushed to downstream elements.
    ///
    /// - Parameters:
    ///   - data: The raw bytes to push.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Push with timestamps
    /// var pts: UInt64 = 0
    /// let duration: UInt64 = 33_333_333  // ~30fps
    ///
    /// try src.push(data: frameBytes, pts: pts, duration: duration)
    /// pts += duration
    /// ```
    public func push(data: [UInt8], pts: UInt64? = nil, duration: UInt64? = nil) throws {
        try data.withUnsafeBytes { buffer in
            try push(bytes: buffer.baseAddress!, count: buffer.count, pts: pts, duration: duration)
        }
    }

    /// Push raw data into the pipeline from a Span (zero-copy).
    ///
    /// This overload accepts a `Span<UInt8>` for efficient zero-copy data passing
    /// when you already have data in a span.
    ///
    /// - Parameters:
    ///   - data: A span of bytes to push.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Push directly from a span without intermediate array allocation
    /// let span: Span<UInt8> = ...
    /// try src.push(data: span, pts: pts, duration: duration)
    /// ```
    public func push(data: borrowing Span<UInt8>, pts: UInt64? = nil, duration: UInt64? = nil) throws {
        try data.withUnsafeBufferPointer { buffer in
            try push(bytes: buffer.baseAddress!, count: buffer.count, pts: pts, duration: duration)
        }
    }

    /// Push raw data into the pipeline from a RawSpan (zero-copy).
    ///
    /// This overload accepts a `RawSpan` for efficient zero-copy data passing
    /// when you already have raw bytes in a span.
    ///
    /// - Parameters:
    ///   - data: A raw span of bytes to push.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Push directly from a raw span (e.g., from a mapped buffer)
    /// try frame.withMappedBytes { span in
    ///     try src.push(data: span, pts: frame.pts, duration: frame.duration)
    /// }
    /// ```
    public func push(data: borrowing RawSpan, pts: UInt64? = nil, duration: UInt64? = nil) throws {
        try data.withUnsafeBytes { buffer in
            try push(bytes: buffer.baseAddress!, count: buffer.count, pts: pts, duration: duration)
        }
    }

    /// Push raw data into the pipeline from a buffer pointer.
    ///
    /// - Parameters:
    ///   - bytes: Pointer to the raw bytes.
    ///   - count: Number of bytes.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    public func push(bytes: UnsafeRawPointer, count: Int, pts: UInt64? = nil, duration: UInt64? = nil) throws {
        let gstPts = pts ?? swift_gst_clock_time_none()
        let gstDuration = duration ?? swift_gst_clock_time_none()

        guard let buffer = swift_gst_buffer_new_wrapped_full(bytes, gsize(count), gstPts, gstDuration) else {
            throw GStreamerError.bufferMapFailed
        }

        // push_buffer takes ownership of the buffer, no need to unref
        let result = swift_gst_app_src_push_buffer(appSrc, buffer)
        if result.rawValue < 0 {  // GST_FLOW_OK = 0, errors are negative
            throw GStreamerError.stateChangeFailed
        }
    }

    /// Push a video frame with explicit dimensions.
    ///
    /// Convenience method for pushing video frame data with format information.
    ///
    /// - Parameters:
    ///   - data: The pixel data.
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - format: The pixel format.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Generate a red frame
    /// let width = 640
    /// let height = 480
    /// var pixels = [UInt8](repeating: 0, count: width * height * 4)
    ///
    /// // Fill with red (BGRA format)
    /// for i in stride(from: 0, to: pixels.count, by: 4) {
    ///     pixels[i] = 0       // Blue
    ///     pixels[i + 1] = 0   // Green
    ///     pixels[i + 2] = 255 // Red
    ///     pixels[i + 3] = 255 // Alpha
    /// }
    ///
    /// try src.pushVideoFrame(
    ///     data: pixels,
    ///     width: width,
    ///     height: height,
    ///     format: .bgra,
    ///     pts: 0,
    ///     duration: 33_333_333
    /// )
    /// ```
    public func pushVideoFrame(
        data: [UInt8],
        width: Int,
        height: Int,
        format: PixelFormat,
        pts: UInt64? = nil,
        duration: UInt64? = nil
    ) throws {
        // Verify data size matches expected size
        let expectedSize = width * height * format.bytesPerPixel
        guard data.count >= expectedSize else {
            throw GStreamerError.bufferMapFailed
        }

        try push(data: data, pts: pts, duration: duration)
    }

    /// Push a video frame with explicit dimensions from a Span (zero-copy).
    ///
    /// Convenience method for pushing video frame data with format information,
    /// accepting a `Span<UInt8>` to avoid intermediate array allocation.
    ///
    /// - Parameters:
    ///   - data: The pixel data as a span.
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - format: The pixel format.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Push frame data directly from a span
    /// let pixelSpan: Span<UInt8> = ...
    /// try src.pushVideoFrame(
    ///     data: pixelSpan,
    ///     width: 640,
    ///     height: 480,
    ///     format: .bgra,
    ///     pts: pts,
    ///     duration: 33_333_333
    /// )
    /// ```
    public func pushVideoFrame(
        data: borrowing Span<UInt8>,
        width: Int,
        height: Int,
        format: PixelFormat,
        pts: UInt64? = nil,
        duration: UInt64? = nil
    ) throws {
        // Verify data size matches expected size
        let expectedSize = width * height * format.bytesPerPixel
        guard data.count >= expectedSize else {
            throw GStreamerError.bufferMapFailed
        }

        try push(data: data, pts: pts, duration: duration)
    }

    /// Push a video frame with explicit dimensions from a RawSpan (zero-copy).
    ///
    /// Convenience method for pushing video frame data with format information,
    /// accepting a `RawSpan` for direct buffer-to-buffer transfer.
    ///
    /// - Parameters:
    ///   - data: The pixel data as a raw span.
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - format: The pixel format.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the push fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Forward frames from one pipeline to another with zero intermediate copies
    /// for await frame in sink.frames() {
    ///     try frame.withMappedBytes { span in
    ///         try src.pushVideoFrame(
    ///             data: span,
    ///             width: frame.width,
    ///             height: frame.height,
    ///             format: frame.format,
    ///             pts: frame.pts,
    ///             duration: frame.duration
    ///         )
    ///     }
    /// }
    /// ```
    public func pushVideoFrame(
        data: borrowing RawSpan,
        width: Int,
        height: Int,
        format: PixelFormat,
        pts: UInt64? = nil,
        duration: UInt64? = nil
    ) throws {
        // Verify data size matches expected size
        let expectedSize = width * height * format.bytesPerPixel
        guard data.byteCount >= expectedSize else {
            throw GStreamerError.bufferMapFailed
        }

        try push(data: data, pts: pts, duration: duration)
    }

    /// Signal end-of-stream to the pipeline.
    ///
    /// Call this when you're done pushing data. Downstream elements will
    /// receive an EOS event and can finalize (e.g., close output files).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Push all frames
    /// for frame in frames {
    ///     try src.push(data: frame)
    /// }
    ///
    /// // Signal we're done
    /// src.endOfStream()
    ///
    /// // Wait for pipeline to finish processing
    /// for await message in pipeline.bus.messages() {
    ///     if case .eos = message { break }
    /// }
    /// ```
    public func endOfStream() {
        _ = swift_gst_app_src_end_of_stream(appSrc)
    }
}
