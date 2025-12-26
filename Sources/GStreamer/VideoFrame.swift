import CGStreamer
import CGStreamerShim

/// A video frame with access to pixel data.
///
/// VideoFrame provides safe, zero-copy access to video frame data from a GStreamer
/// pipeline. Use ``withMappedBytes(_:)`` to access the raw pixel data.
///
/// ## Overview
///
/// VideoFrame is designed for high-performance video processing. The pixel data
/// is accessed through a closure-based API that ensures memory safety - the raw
/// bytes cannot escape the closure scope.
///
/// ## Topics
///
/// ### Frame Properties
///
/// - ``width``
/// - ``height``
/// - ``format``
///
/// ### Timestamps
///
/// - ``pts``
/// - ``dts``
/// - ``duration``
///
/// ### Accessing Pixel Data
///
/// - ``withMappedBytes(_:)``
///
/// ## Example
///
/// ```swift
/// for await frame in sink.frames() {
///     print("Frame: \(frame.width)x\(frame.height) \(frame.format)")
///
///     // Access pixel data safely
///     try frame.withMappedBytes { span in
///         span.withUnsafeBytes { buffer in
///             // buffer is UnsafeRawBufferPointer
///             for i in stride(from: 0, to: buffer.count, by: 4) {
///                 let b = buffer[i]     // Blue
///                 let g = buffer[i + 1] // Green
///                 let r = buffer[i + 2] // Red
///                 let a = buffer[i + 3] // Alpha
///                 // Process BGRA pixel...
///             }
///         }
///     }
/// }
/// ```
///
/// ## Memory Safety
///
/// The ``withMappedBytes(_:)`` method uses Swift's `RawSpan` to provide safe
/// access to the underlying buffer. The span cannot escape the closure, ensuring
/// the buffer remains valid for the duration of access.
///
/// ```swift
/// // This is safe - data is processed within the closure
/// try frame.withMappedBytes { span in
///     span.withUnsafeBytes { buffer in
///         processPixels(buffer)
///     }
/// }
///
/// // The buffer is automatically unmapped when the closure returns
/// ```
///
/// ## Timestamps
///
/// Each frame includes timing information for synchronization:
///
/// ```swift
/// for await frame in sink.frames() {
///     if let pts = frame.pts {
///         print("Frame at \(Double(pts) / 1_000_000_000.0)s")
///     }
///     if let duration = frame.duration {
///         print("Duration: \(Double(duration) / 1_000_000.0)ms")
///     }
/// }
/// ```
public struct VideoFrame: @unchecked Sendable {
    /// The width of the frame in pixels.
    public let width: Int

    /// The height of the frame in pixels.
    public let height: Int

    /// The pixel format of the frame.
    ///
    /// Common formats include:
    /// - `.bgra`: 32-bit BGRA (common on macOS/iOS)
    /// - `.rgba`: 32-bit RGBA
    /// - `.nv12`: YUV 4:2:0 (common for video codecs)
    /// - `.i420`: YUV 4:2:0 planar
    /// - `.gray8`: 8-bit grayscale
    public let format: PixelFormat

    /// The presentation timestamp (PTS) in nanoseconds.
    ///
    /// This indicates when the frame should be displayed. Returns `nil` if
    /// the timestamp is not set (GST_CLOCK_TIME_NONE).
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let pts = frame.pts {
    ///     let seconds = Double(pts) / 1_000_000_000.0
    ///     print("Frame time: \(seconds)s")
    /// }
    /// ```
    public var pts: UInt64? {
        let value = swift_gst_buffer_get_pts(storage.buffer)
        return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
    }

    /// The decode timestamp (DTS) in nanoseconds.
    ///
    /// This indicates when the frame should be decoded. For most video formats,
    /// DTS equals PTS. For formats with B-frames, DTS may differ.
    /// Returns `nil` if not set.
    public var dts: UInt64? {
        let value = swift_gst_buffer_get_dts(storage.buffer)
        return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
    }

    /// The duration of the frame in nanoseconds.
    ///
    /// Returns `nil` if the duration is not set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let duration = frame.duration {
    ///     let fps = 1_000_000_000.0 / Double(duration)
    ///     print("Frame rate: \(fps) fps")
    /// }
    /// ```
    public var duration: UInt64? {
        let value = swift_gst_buffer_get_duration(storage.buffer)
        return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
    }

    /// Storage class to manage the buffer lifecycle.
    private final class Storage: @unchecked Sendable {
        let buffer: UnsafeMutablePointer<GstBuffer>
        let ownsReference: Bool

        init(buffer: UnsafeMutablePointer<GstBuffer>, ownsReference: Bool) {
            self.buffer = buffer
            self.ownsReference = ownsReference
        }

        deinit {
            if ownsReference {
                swift_gst_buffer_unref(buffer)
            }
        }
    }

    private let storage: Storage

    /// Create a VideoFrame from a GstBuffer and video info.
    internal init(
        buffer: UnsafeMutablePointer<GstBuffer>,
        width: Int,
        height: Int,
        format: PixelFormat,
        ownsReference: Bool
    ) {
        self.storage = Storage(buffer: buffer, ownsReference: ownsReference)
        self.width = width
        self.height = height
        self.format = format
    }

    /// Access the frame's pixel data for reading.
    ///
    /// This method maps the buffer into memory and provides safe access through
    /// a `RawSpan`. The buffer is automatically unmapped when the closure returns.
    ///
    /// - Parameter body: A closure that receives a `RawSpan` to the pixel data.
    /// - Returns: The value returned by the closure.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if the buffer cannot be mapped,
    ///           or rethrows any error from the closure.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Calculate average brightness
    /// let brightness = try frame.withMappedBytes { span in
    ///     span.withUnsafeBytes { buffer in
    ///         var total: Int = 0
    ///         for i in stride(from: 0, to: buffer.count, by: 4) {
    ///             // Average of RGB channels
    ///             total += Int(buffer[i]) + Int(buffer[i+1]) + Int(buffer[i+2])
    ///         }
    ///         return total / (buffer.count / 4) / 3
    ///     }
    /// }
    /// print("Average brightness: \(brightness)")
    /// ```
    ///
    /// ## Integration with Vision/CoreML
    ///
    /// ```swift
    /// try frame.withMappedBytes { span in
    ///     span.withUnsafeBytes { buffer in
    ///         // Create CVPixelBuffer for Vision
    ///         var pixelBuffer: CVPixelBuffer?
    ///         CVPixelBufferCreateWithBytes(
    ///             nil,
    ///             frame.width,
    ///             frame.height,
    ///             kCVPixelFormatType_32BGRA,
    ///             UnsafeMutableRawPointer(mutating: buffer.baseAddress!),
    ///             frame.width * 4,
    ///             nil, nil, nil,
    ///             &pixelBuffer
    ///         )
    ///         // Use with VNImageRequestHandler...
    ///     }
    /// }
    /// ```
    public func withMappedBytes<R>(_ body: (RawSpan) throws -> R) throws -> R {
        var mapInfo = GstMapInfo()
        guard swift_gst_buffer_map_read(storage.buffer, &mapInfo) != 0 else {
            throw GStreamerError.bufferMapFailed
        }
        defer {
            swift_gst_buffer_unmap(storage.buffer, &mapInfo)
        }

        let span = RawSpan(_unsafeStart: mapInfo.data, byteCount: Int(mapInfo.size))
        return try body(span)
    }
}
