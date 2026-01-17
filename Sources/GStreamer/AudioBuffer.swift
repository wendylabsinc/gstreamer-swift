import CGStreamer
import CGStreamerShim

/// An audio buffer with access to sample data.
///
/// AudioBuffer provides safe, zero-copy access to audio sample data from a GStreamer
/// pipeline. Use ``bytes`` to access the raw sample data.
///
/// ## Overview
///
/// AudioBuffer is designed for high-performance audio processing. The sample data
/// is accessed through a lifetime-bound span that ensures memory safety.
///
/// ## Topics
///
/// ### Buffer Properties
///
/// - ``sampleRate``
/// - ``channels``
/// - ``format``
/// - ``sampleCount``
///
/// ### Timestamps
///
/// - ``pts``
/// - ``duration``
///
/// ### Accessing Sample Data
///
/// - ``bytes``
///
/// ## Example
///
/// ```swift
/// for await buffer in audioSink.buffers() {
///     print("Audio: \(buffer.sampleRate)Hz, \(buffer.channels)ch, \(buffer.format)")
///
///     if let pts = buffer.pts {
///         print("Time: \(Double(pts) / 1_000_000_000.0)s")
///     }
///
///     // Access raw bytes via subscript
///     let firstByte = buffer.bytes[0]
/// }
/// ```
public struct AudioBuffer: @unchecked Sendable {
    /// The sample rate in Hz.
    public let sampleRate: Int

    /// The number of audio channels.
    public let channels: Int

    /// The audio sample format.
    public let format: AudioFormat

    /// The number of samples per channel in this buffer.
    public var sampleCount: Int {
        let bytesPerFrame = format.bytesPerSample * channels
        guard bytesPerFrame > 0 else { return 0 }
        return Int(swift_gst_buffer_get_size(storage.buffer)) / bytesPerFrame
    }

    /// The presentation timestamp (PTS) in nanoseconds.
    ///
    /// Returns `nil` if the timestamp is not set.
    public var pts: UInt64? {
        let value = swift_gst_buffer_get_pts(storage.buffer)
        return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
    }

    /// The duration of the buffer in nanoseconds.
    ///
    /// Returns `nil` if the duration is not set.
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

    /// Create an AudioBuffer from a GstBuffer and audio info.
    internal init(
        buffer: UnsafeMutablePointer<GstBuffer>,
        sampleRate: Int,
        channels: Int,
        format: AudioFormat,
        ownsReference: Bool
    ) {
        self.storage = Storage(buffer: buffer, ownsReference: ownsReference)
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
    }

    /// The buffer's sample data as a read-only span.
    ///
    /// This property provides lifetime-bound access to the buffer's bytes.
    /// The span cannot escape the scope in which it's accessed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Read raw bytes
    /// let firstByte = buffer.bytes[0]
    /// let byteCount = buffer.bytes.byteCount
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
}

// MARK: - CustomStringConvertible

extension AudioBuffer: CustomStringConvertible {
    /// A human-readable description of the audio buffer.
    ///
    /// Format: "SAMPLE_RATEHz CHANNELSch FORMAT (SAMPLE_COUNT samples)"
    /// e.g., "48000Hz 2ch S16LE (1024 samples)"
    public var description: String {
        var result = "\(sampleRate)Hz \(channels)ch \(format) (\(sampleCount) samples)"
        if let pts = pts {
            let timestamp = Timestamp(nanoseconds: pts)
            result += " @ \(timestamp.formatted)"
        }
        return result
    }
}
