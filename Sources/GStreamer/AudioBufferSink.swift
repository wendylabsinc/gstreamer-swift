import CGStreamer
import CGStreamerApp
import CGStreamerShim
import Synchronization

/// A wrapper for GStreamer's appsink element for pulling audio buffers from a pipeline.
///
/// AudioBufferSink allows your application to receive audio buffers from a GStreamer pipeline.
/// This is essential for speech recognition, audio analysis, and voice assistants.
///
/// ## Overview
///
/// Use AudioBufferSink to pull audio buffers from a pipeline into your Swift application.
/// The ``buffers()`` method returns an `AsyncStream` that yields ``AudioBuffer``
/// objects as they become available.
///
/// ## Topics
///
/// ### Creating an AudioBufferSink
///
/// - ``init(pipeline:name:)``
///
/// ### Receiving Buffers
///
/// - ``buffers()``
///
/// ## Example
///
/// ```swift
/// // Create a pipeline with an audio appsink
/// let pipeline = try Pipeline("""
///     alsasrc device=default ! \
///     audioconvert ! \
///     audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
///     appsink name=sink
///     """)
///
/// let sink = try AudioBufferSink(pipeline: pipeline, name: "sink")
/// try pipeline.play()
///
/// // Process audio buffers as they arrive
/// for await buffer in sink.buffers() {
///     print("Audio: \(buffer.sampleRate)Hz, \(buffer.channels)ch")
///
///     try buffer.withMappedBytes { span in
///         span.withUnsafeBytes { bytes in
///             // Process audio samples...
///         }
///     }
/// }
/// ```
///
/// ## Voice Assistant Example
///
/// ```swift
/// // Capture audio for wake word detection
/// let pipeline = try Pipeline("""
///     pulsesrc ! \
///     audioconvert ! \
///     audio/x-raw,format=F32LE,rate=16000,channels=1 ! \
///     appsink name=sink
///     """)
///
/// let sink = try AudioBufferSink(pipeline: pipeline, name: "sink")
/// try pipeline.play()
///
/// for await buffer in sink.buffers() {
///     try buffer.withMappedBytes { span in
///         span.withUnsafeBytes { bytes in
///             let samples = Array(bytes.bindMemory(to: Float.self))
///
///             if wakeWordDetector.detect(samples) {
///                 print("Wake word detected!")
///                 // Start full speech recognition...
///             }
///         }
///     }
/// }
/// ```
///
/// ## NVIDIA Jetson Audio
///
/// ```swift
/// // Capture from USB microphone on Jetson
/// let pipeline = try Pipeline("""
///     alsasrc device=hw:1,0 ! \
///     audioconvert ! \
///     audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
///     appsink name=sink
///     """)
///
/// let sink = try AudioBufferSink(pipeline: pipeline, name: "sink")
/// try pipeline.play()
///
/// for await buffer in sink.buffers() {
///     // Feed to TensorRT speech model
/// }
/// ```
public final class AudioBufferSink: @unchecked Sendable {
  /// The underlying element.
  private let element: Element

  /// The GstAppSink pointer (cast from GstElement).
  private var appSink: UnsafeMutablePointer<GstAppSink> {
    UnsafeMutableRawPointer(element.element).assumingMemoryBound(to: GstAppSink.self)
  }

  /// Cached audio info from caps (thread-safe).
  private struct AudioInfo: Sendable {
    var sampleRate: Int = 0
    var channels: Int = 0
    var format: AudioFormat = .unknown("")
  }
  private let cachedInfo = Mutex(AudioInfo())

  /// Create an AudioBufferSink from a pipeline by element name.
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
  /// let pipeline = try Pipeline("alsasrc ! audioconvert ! appsink name=audiosink")
  /// let sink = try AudioBufferSink(pipeline: pipeline, name: "audiosink")
  /// ```
  public init(pipeline: Pipeline, name: String) throws {
    guard let element = pipeline.element(named: name) else {
      throw GStreamerError.elementNotFound(name)
    }
    self.element = element
  }

  /// An async stream of audio buffers from this sink.
  ///
  /// Buffers are yielded as they become available from the pipeline.
  /// The stream ends when the pipeline reaches end-of-stream (EOS).
  ///
  /// - Returns: An `AsyncStream` of ``AudioBuffer`` values.
  ///
  /// ## Example
  ///
  /// ```swift
  /// for await buffer in sink.buffers() {
  ///     print("Received \(buffer.sampleCount) samples at \(buffer.sampleRate)Hz")
  ///
  ///     try buffer.withMappedBytes { span in
  ///         span.withUnsafeBytes { bytes in
  ///             // Process audio...
  ///         }
  ///     }
  /// }
  /// ```
  public func buffers() -> AsyncStream<AudioBuffer> {
    AsyncStream { continuation in
      let task = Task.detached { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        while !Task.isCancelled {
          // Try to pull a sample with 100ms timeout
          if let sample = swift_gst_app_sink_try_pull_sample(self.appSink, 100_000_000) {
            defer { swift_gst_sample_unref(UnsafeMutableRawPointer(sample)) }

            // Get buffer from sample
            guard let buffer = swift_gst_sample_get_buffer(UnsafeMutableRawPointer(sample)) else {
              continue
            }

            // Get current cached info
            var info = self.cachedInfo.withLock { $0 }

            // Parse audio info from caps
            if info.sampleRate == 0 {
              if let caps = swift_gst_sample_get_caps(UnsafeMutableRawPointer(sample)) {
                info = self.parseAudioInfo(from: caps)
              }
            }

            // Get buffer size to validate
            let bufferSize = swift_gst_buffer_get_size(buffer)
            guard bufferSize > 0 else { continue }

            // Ref the buffer so AudioBuffer can own it
            _ = swift_gst_buffer_ref(buffer)

            let audioBuffer = AudioBuffer(
              buffer: buffer,
              sampleRate: info.sampleRate,
              channels: info.channels,
              format: info.format,
              ownsReference: true
            )

            continuation.yield(audioBuffer)
          }

          // Check for EOS
          if swift_gst_app_sink_is_eos(self.appSink) != 0 {
            break
          }
        }

        continuation.finish()
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  /// Parse audio info from caps and update cache.
  private func parseAudioInfo(from caps: UnsafeMutablePointer<GstCaps>) -> AudioInfo {
    guard let string = GLibString.takeOwnership(swift_gst_caps_to_string(caps)) else {
      return cachedInfo.withLock { $0 }
    }
    let components = string.split(separator: ",")

    var info = AudioInfo()

    for component in components {
      let trimmed = component.trimmingWhitespace()
      if trimmed.hasPrefix("rate=") {
        let value = extractValue(from: String(trimmed.dropFirst(5)))
        info.sampleRate = Int(value) ?? 0
      } else if trimmed.hasPrefix("channels=") {
        let value = extractValue(from: String(trimmed.dropFirst(9)))
        info.channels = Int(value) ?? 0
      } else if trimmed.hasPrefix("format=") {
        let value = extractValue(from: String(trimmed.dropFirst(7)))
        info.format = AudioFormat(string: value)
      }
    }

    // Update cache atomically
    cachedInfo.withLock { $0 = info }
    return info
  }

  /// Extract value from a GStreamer caps value that may have type annotation.
  private func extractValue(from string: String) -> String {
    if let closeParenIndex = string.firstIndex(of: ")"),
      string.hasPrefix("(")
    {
      return String(string[string.index(after: closeParenIndex)...])
    }
    return string
  }
}
