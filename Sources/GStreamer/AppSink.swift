import CGStreamer
import CGStreamerApp
import CGStreamerShim
import Foundation
import Synchronization

/// A wrapper for GStreamer's appsink element for pulling video frames from a pipeline.
///
/// AppSink allows your application to receive buffers from a GStreamer pipeline.
/// This is essential for computer vision, machine learning inference, and any
/// application that needs to process raw video frames.
///
/// ## Overview
///
/// Use AppSink to pull video frames from a pipeline into your Swift application.
/// The ``frames()`` method returns an `AsyncStream` that yields ``VideoFrame``
/// objects as they become available.
///
/// ## Topics
///
/// ### Creating an AppSink
///
/// - ``init(pipeline:name:)``
///
/// ### Receiving Frames
///
/// - ``frames()``
///
/// ## Example
///
/// ```swift
/// // Create a pipeline with an appsink
/// let pipeline = try Pipeline("""
///     videotestsrc num-buffers=100 ! \
///     video/x-raw,format=BGRA,width=640,height=480 ! \
///     appsink name=sink
///     """)
///
/// let sink = try AppSink(pipeline: pipeline, name: "sink")
/// try pipeline.play()
///
/// // Process frames as they arrive
/// for await frame in sink.frames() {
///     print("Frame: \(frame.width)x\(frame.height)")
///
///     try frame.withMappedBytes { span in
///         span.withUnsafeBytes { buffer in
///             // Process raw pixel data...
///         }
///     }
/// }
/// ```
///
/// ## Webcam Capture Example
///
/// ```swift
/// // Linux webcam capture
/// let pipeline = try Pipeline("""
///     v4l2src device=/dev/video0 ! \
///     videoconvert ! \
///     video/x-raw,format=BGRA,width=640,height=480 ! \
///     appsink name=sink
///     """)
///
/// let sink = try AppSink(pipeline: pipeline, name: "sink")
/// try pipeline.play()
///
/// for await frame in sink.frames() {
///     // Each frame is a webcam capture
///     try frame.withMappedBytes { span in
///         // Send to ML model, save to disk, etc.
///     }
/// }
/// ```
public final class AppSink: @unchecked Sendable {
    /// The underlying element.
    private let element: Element

    /// The GstAppSink pointer (cast from GstElement).
    private var appSink: UnsafeMutablePointer<GstAppSink> {
        UnsafeMutableRawPointer(element.element).assumingMemoryBound(to: GstAppSink.self)
    }

    /// Cached video info from caps (thread-safe).
    private struct VideoInfo: Sendable {
        var width: Int = 0
        var height: Int = 0
        var format: PixelFormat = .unknown("")
    }
    private let cachedInfo = Mutex(VideoInfo())

    /// Create an AppSink from a pipeline by element name.
    ///
    /// The element must be an `appsink` element in the pipeline.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline containing the appsink.
    ///   - name: The name of the appsink element (from `name=...` in pipeline).
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if no element with that name exists.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("videotestsrc ! appsink name=mysink")
    /// let sink = try AppSink(pipeline: pipeline, name: "mysink")
    /// ```
    public init(pipeline: Pipeline, name: String) throws {
        guard let element = pipeline.element(named: name) else {
            throw GStreamerError.elementNotFound(name)
        }
        self.element = element
    }
    public struct Frames: AsyncSequence {
        let sink: AppSink
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            let sink: AppSink

            @concurrent
            public func next() async throws -> VideoFrame? {
                while !Task.isCancelled {
                    // Try to pull a sample with 100ms timeout
                    if let sample = swift_gst_app_sink_try_pull_sample(sink.appSink, 100_000_000) {
                        defer { swift_gst_sample_unref(UnsafeMutableRawPointer(sample)) }

                        // Get buffer from sample
                        guard let buffer = swift_gst_sample_get_buffer(UnsafeMutableRawPointer(sample)) else {
                            continue
                        }

                        // Get current cached info
                        var info = sink.cachedInfo.withLock { $0 }

                        // Parse video info from caps - always try until we have valid values
                        if info.width == 0 || info.height == 0 {
                            if let caps = swift_gst_sample_get_caps(UnsafeMutableRawPointer(sample)) {
                                info = sink.parseVideoInfo(from: caps)
                            }
                        }

                        // Get buffer size to validate
                        let bufferSize = swift_gst_buffer_get_size(buffer)
                        guard bufferSize > 0 else { continue }

                        // If we still don't have dimensions, try to infer from buffer size and format
                        var width = info.width
                        var height = info.height
                        let format = info.format

                        if width == 0 || height == 0 {
                            // Try to infer dimensions from buffer size
                            let bytesPerPixel = format.bytesPerPixel
                            if bytesPerPixel > 0 {
                                let totalPixels = Int(bufferSize) / bytesPerPixel
                                // Common aspect ratios to try
                                let aspectRatios: [(Int, Int)] = [(16, 9), (4, 3), (1, 1)]
                                for (w, h) in aspectRatios {
                                    let testWidth = Int(sqrt(Double(totalPixels * w / h)))
                                    let testHeight = totalPixels / testWidth
                                    if testWidth * testHeight == totalPixels {
                                        width = testWidth
                                        height = testHeight
                                        // Cache for subsequent frames
                                        sink.cachedInfo.withLock {
                                            $0.width = width
                                            $0.height = height
                                        }
                                        break
                                    }
                                }
                            }
                        }

                        // Ref the buffer so VideoFrame can own it
                        _ = swift_gst_buffer_ref(buffer)

                        let frame = VideoFrame(
                            buffer: buffer,
                            width: width,
                            height: height,
                            format: format,
                            ownsReference: true
                        )

                        return frame
                    }

                    // Check for EOS
                    if swift_gst_app_sink_is_eos(sink.appSink) != 0 {
                        break
                    }

                    await Task.yield()
                }
                
                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(sink: sink)
        }
    }

    /// An async stream of video frames from this sink.
    ///
    /// Frames are yielded as they become available from the pipeline.
    /// The stream ends when the pipeline reaches end-of-stream (EOS).
    ///
    /// - Returns: An `AsyncStream` of ``VideoFrame`` values.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await frame in sink.frames() {
    ///     print("Received \(frame.width)x\(frame.height) frame")
    ///
    ///     // Access pixel data safely
    ///     try frame.withMappedBytes { span in
    ///         span.withUnsafeBytes { buffer in
    ///             let pixels = Array(buffer)
    ///             // Process pixels...
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## NVIDIA Jetson Example
    ///
    /// ```swift
    /// // Jetson camera with hardware acceleration
    /// let pipeline = try Pipeline("""
    ///     nvarguscamerasrc ! \
    ///     video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1 ! \
    ///     nvvidconv ! \
    ///     video/x-raw,format=BGRA ! \
    ///     appsink name=sink
    ///     """)
    ///
    /// let sink = try AppSink(pipeline: pipeline, name: "sink")
    /// try pipeline.play()
    ///
    /// for await frame in sink.frames() {
    ///     // Process 1080p frames from Jetson camera
    /// }
    /// ```
    public func frames() -> Frames {
        Frames(sink: self)
    }

    /// Parse video info from caps and update cache.
    private func parseVideoInfo(from caps: UnsafeMutablePointer<GstCaps>) -> VideoInfo {
        guard let capsString = swift_gst_caps_to_string(caps) else {
            return cachedInfo.withLock { $0 }
        }
        defer { g_free(capsString) }

        let string = String(cString: capsString)
        let components = string.split(separator: ",")

        var info = VideoInfo()

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("width=") {
                // Handle both "width=320" and "width=(int)320"
                let value = extractValue(from: String(trimmed.dropFirst(6)))
                info.width = Int(value) ?? 0
            } else if trimmed.hasPrefix("height=") {
                let value = extractValue(from: String(trimmed.dropFirst(7)))
                info.height = Int(value) ?? 0
            } else if trimmed.hasPrefix("format=") {
                let value = extractValue(from: String(trimmed.dropFirst(7)))
                info.format = PixelFormat(string: value)
            }
        }

        // Update cache atomically
        cachedInfo.withLock { $0 = info }
        return info
    }

    /// Extract value from a GStreamer caps value that may have type annotation.
    /// Handles both "BGRA" and "(string)BGRA" and "(int)320".
    private func extractValue(from string: String) -> String {
        // Check for type annotation pattern like "(type)value"
        if let closeParenIndex = string.firstIndex(of: ")"),
           string.hasPrefix("(") {
            return String(string[string.index(after: closeParenIndex)...])
        }
        return string
    }
}
