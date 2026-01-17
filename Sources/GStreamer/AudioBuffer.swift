import CGStreamer
import CGStreamerShim

/// An audio buffer with access to sample data.
///
/// AudioBuffer provides safe, zero-copy access to audio sample data from a GStreamer
/// pipeline. Use ``withMappedBytes(_:)`` to access the raw sample data.
///
/// ## Overview
///
/// AudioBuffer is designed for high-performance audio processing. The sample data
/// is accessed through a closure-based API that ensures memory safety.
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
/// - ``withMappedBytes(_:)``
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
///     try buffer.withMappedBytes { span in
///         span.withUnsafeBytes { bytes in
///             // Process S16LE samples
///             let samples = bytes.bindMemory(to: Int16.self)
///             let rms = calculateRMS(samples)
///             print("RMS level: \(rms)")
///         }
///     }
/// }
/// ```
///
/// ## Speech Recognition Example
///
/// ```swift
/// // Capture audio for speech recognition
/// let pipeline = try Pipeline("""
///     alsasrc device=default ! \
///     audioconvert ! \
///     audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
///     appsink name=sink
///     """)
///
/// let sink = try AudioSink(pipeline: pipeline, name: "sink")
/// try pipeline.play()
///
/// for await buffer in sink.buffers() {
///     try buffer.withMappedBytes { span in
///         span.withUnsafeBytes { bytes in
///             // Feed to speech recognition model
///             let samples = Array(bytes.bindMemory(to: Int16.self))
///             speechRecognizer.process(samples)
///         }
///     }
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

    /// Access the buffer's sample data for reading.
    ///
    /// This method maps the buffer into memory and provides safe access through
    /// a `RawSpan`. The buffer is automatically unmapped when the closure returns.
    ///
    /// - Parameter body: A closure that receives a `RawSpan` to the sample data.
    /// - Returns: The value returned by the closure.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if the buffer cannot be mapped.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Process S16LE audio samples
    /// try buffer.withMappedBytes { span in
    ///     span.withUnsafeBytes { bytes in
    ///         let samples = bytes.bindMemory(to: Int16.self)
    ///
    ///         // Calculate peak amplitude
    ///         var peak: Int16 = 0
    ///         for sample in samples {
    ///             peak = max(peak, abs(sample))
    ///         }
    ///
    ///         let normalized = Float(peak) / Float(Int16.max)
    ///         print("Peak level: \(normalized)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Stereo Processing
    ///
    /// ```swift
    /// // Process stereo audio (channels are interleaved)
    /// try buffer.withMappedBytes { span in
    ///     span.withUnsafeBytes { bytes in
    ///         let samples = bytes.bindMemory(to: Int16.self)
    ///
    ///         for i in stride(from: 0, to: samples.count, by: 2) {
    ///             let left = samples[i]
    ///             let right = samples[i + 1]
    ///             // Process stereo pair...
    ///         }
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
