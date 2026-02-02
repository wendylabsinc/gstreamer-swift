import CGStreamer
import CGStreamerShim

/// A video frame with access to pixel data.
///
/// VideoFrame provides safe, zero-copy access to video frame data from a GStreamer
/// pipeline. Use ``bytes`` to access the raw pixel data.
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
/// - ``bytes``
///
/// ## Example
///
/// ```swift
/// for await frame in sink.frames() {
///     print("Frame: \(frame.width)x\(frame.height) \(frame.format)")
///
///     // Access pixel data safely via subscript
///     for i in stride(from: 0, to: frame.bytes.byteCount, by: 4) {
///         let b = frame.bytes[i]     // Blue
///         let g = frame.bytes[i + 1] // Green
///         let r = frame.bytes[i + 2] // Red
///         let a = frame.bytes[i + 3] // Alpha
///         // Process BGRA pixel...
///     }
/// }
/// ```
///
/// ## Memory Safety
///
/// The ``bytes`` property uses Swift's `RawSpan` to provide lifetime-bound
/// access to the underlying buffer:
///
/// ```swift
/// let firstByte = frame.bytes[0]
/// let byteCount = frame.bytes.byteCount
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

    // MARK: - Pixel Data Access

    /// The frame's pixel data as a read-only span.
    ///
    /// This property provides lifetime-bound access to the frame's bytes.
    /// The span cannot escape the scope in which it's accessed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await frame in sink.frames() {
    ///     for i in stride(from: 0, to: frame.bytes.byteCount, by: 4) {
    ///         let b = frame.bytes[i]     // Blue
    ///         let g = frame.bytes[i + 1] // Green
    ///         let r = frame.bytes[i + 2] // Red
    ///         let a = frame.bytes[i + 3] // Alpha
    ///     }
    /// }
    /// ```
    public var bytes: RawSpan {
        _read {
            var mapInfo = GstMapInfo()
            guard swift_gst_buffer_map_read(storage.buffer, &mapInfo) != 0 else {
                fatalError("Failed to map buffer for reading")
            }
            defer { swift_gst_buffer_unmap(storage.buffer, &mapInfo) }
            yield RawSpan(_unsafeStart: mapInfo.data, byteCount: Int(mapInfo.size))
        }
    }

    /// The frame's pixel data as a mutable span.
    ///
    /// This property provides lifetime-bound mutable access to the frame's bytes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Invert colors in-place
    /// for i in stride(from: 0, to: frame.mutableBytes.byteCount, by: 4) {
    ///     frame.mutableBytes[i] = 255 - frame.mutableBytes[i]         // Blue
    ///     frame.mutableBytes[i + 1] = 255 - frame.mutableBytes[i + 1] // Green
    ///     frame.mutableBytes[i + 2] = 255 - frame.mutableBytes[i + 2] // Red
    /// }
    /// ```
    public var mutableBytes: MutableRawSpan {
        _read {
            fatalError("Cannot read mutableBytes")
        }
        _modify {
            var mapInfo = GstMapInfo()
            guard swift_gst_buffer_map_write(storage.buffer, &mapInfo) != 0 else {
                fatalError("Failed to map buffer for writing")
            }
            defer { swift_gst_buffer_unmap(storage.buffer, &mapInfo) }
            var span = MutableRawSpan(_unsafeStart: mapInfo.data, byteCount: Int(mapInfo.size))
            yield &span
        }
    }

    /// Access the frame's pixel data using unsafe read-only pointers.
    ///
    /// This method provides direct pointer access for interoperability with C APIs.
    /// Prefer ``bytes`` when possible.
    ///
    /// - Parameter body: A closure that receives an UnsafeRawBufferPointer.
    /// - Returns: The value returned by the closure.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if mapping fails.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        var mapInfo = GstMapInfo()
        guard swift_gst_buffer_map_read(storage.buffer, &mapInfo) != 0 else {
            throw GStreamerError.bufferMapFailed
        }
        defer {
            swift_gst_buffer_unmap(storage.buffer, &mapInfo)
        }

        let ptr = UnsafeRawBufferPointer(start: mapInfo.data, count: Int(mapInfo.size))
        return try body(ptr)
    }

    /// Access the frame's pixel data using unsafe mutable pointers.
    ///
    /// This method provides direct pointer access for interoperability with C APIs
    /// or performance-critical code. Prefer ``mutableBytes`` when possible.
    ///
    /// - Parameter body: A closure that receives an UnsafeMutableRawBufferPointer.
    /// - Returns: The value returned by the closure.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if mapping fails.
    public func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        var mapInfo = GstMapInfo()
        guard swift_gst_buffer_map_write(storage.buffer, &mapInfo) != 0 else {
            throw GStreamerError.bufferMapFailed
        }
        defer {
            swift_gst_buffer_unmap(storage.buffer, &mapInfo)
        }

        let ptr = UnsafeMutableRawBufferPointer(start: mapInfo.data, count: Int(mapInfo.size))
        return try body(ptr)
    }
}

// MARK: - CustomStringConvertible

extension VideoFrame: CustomStringConvertible {
    /// A human-readable description of the video frame.
    ///
    /// Format: "WIDTHxHEIGHT FORMAT @ TIMEs" (e.g., "1920x1080 BGRA @ 1.234s")
    public var description: String {
        var result = "\(width)x\(height) \(format)"
        if let pts = pts {
            let timestamp = Timestamp(nanoseconds: pts)
            result += " @ \(timestamp.formatted)"
        }
        return result
    }
}
