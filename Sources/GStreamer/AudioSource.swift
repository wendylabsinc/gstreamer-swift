import CGStreamer
import CGStreamerApp
import CGStreamerShim

/// High-level microphone capture API with automatic source selection and encoding.
///
/// AudioSource provides a fluent builder for common microphone pipelines,
/// including sample rate, channel count, format, and optional encoding.
///
/// ## Example
///
/// ```swift
/// let mic = try AudioSource.microphone()
///     .withSampleRate(48_000)
///     .withChannels(2)
///     .withFormat(.s16le)
///     .withOpusEncoding(bitrate: 128_000)
///     .build()
///
/// for await packet in mic.packets() {
///     // Process encoded audio packets
/// }
/// ```
public final class AudioSource: @unchecked Sendable {
  /// Output encoding for audio capture.
  public enum Encoding: Sendable, Hashable {
    case raw
    case opus(bitrate: Int)
    case aac(bitrate: Int)
  }

  /// Errors that can occur when building an audio source.
  public enum AudioSourceError: Error, Sendable, CustomStringConvertible {
    case deviceNotFound(String)
    case devicePathUnsupported(String)
    case invalidConfiguration(String)
    case noWorkingPipeline([String])

    public var description: String {
      switch self {
      case .deviceNotFound(let name):
        return "No microphone found matching: \(name)"
      case .devicePathUnsupported(let path):
        return "Device path not supported on this platform: \(path)"
      case .invalidConfiguration(let message):
        return "Invalid AudioSource configuration: \(message)"
      case .noWorkingPipeline(let diagnostics):
        if diagnostics.isEmpty {
          return "No working audio pipeline found"
        }
        return "No working audio pipeline found. Attempts:\n" + diagnostics.joined(separator: "\n")
      }
    }
  }

  private let pipeline: Pipeline
  private let audioSink: AudioSink?
  private let packetSink: AudioPacketSink?
  private let pipelineDescription: String
  private let buildDiagnostics: [String]

  /// The encoding configured for this source.
  public let encoding: Encoding

  fileprivate init(
    pipeline: Pipeline,
    audioSink: AudioSink?,
    packetSink: AudioPacketSink?,
    pipelineDescription: String,
    diagnostics: [String],
    encoding: Encoding
  ) {
    self.pipeline = pipeline
    self.audioSink = audioSink
    self.packetSink = packetSink
    self.pipelineDescription = pipelineDescription
    self.buildDiagnostics = diagnostics
    self.encoding = encoding
  }

  deinit {
    pipeline.stop()
  }

  /// The selected pipeline description used to build this source.
  public var selectedPipeline: String {
    pipelineDescription
  }

  /// Diagnostics from pipeline selection and fallback attempts.
  public var diagnostics: [String] {
    buildDiagnostics
  }

  /// An async stream of raw audio buffers.
  ///
  /// - Note: Only available when encoding is ``AudioSource/Encoding/raw``.
  ///   For encoded output, use ``packets()``.
  public func buffers() -> AsyncStream<AudioBuffer> {
    guard let audioSink else {
      return AsyncStream { $0.finish() }
    }
    return audioSink.buffers()
  }

  /// An async stream of encoded (or raw) audio packets.
  ///
  /// For raw capture, this returns an empty stream. Prefer ``buffers()``.
  public func packets() -> AsyncStream<Buffer> {
    guard let packetSink else {
      return AsyncStream { $0.finish() }
    }
    return packetSink.packets()
  }

  /// Stop the underlying pipeline.
  public func stop() async {
    pipeline.stop()
  }

  /// Discover available microphones on the system.
  public static func availableMicrophones() throws -> [AudioDeviceInfo] {
    let monitor = DeviceMonitor()
    let devices = monitor.audioSources()

    return devices.enumerated().map { index, device in
      let uniqueID = AudioSource.uniqueID(for: device, index: index)
      let capabilities = AudioSource.parseCapabilities(device.caps)
      return AudioDeviceInfo(
        index: index,
        name: device.displayName,
        uniqueID: uniqueID,
        type: .input,
        capabilities: capabilities
      )
    }
  }

  /// Create a microphone source using the default device (typically index 0).
  public static func microphone(deviceIndex: Int = 0) -> AudioSourceBuilder {
    AudioSourceBuilder(selection: .deviceIndex(deviceIndex))
  }

  /// Create a microphone source by matching a device display name.
  public static func microphone(name: String) throws -> AudioSourceBuilder {
    let resolved = try resolveDeviceSelection(forName: name)
    return AudioSourceBuilder(selection: resolved)
  }

  /// Create a microphone source using a platform-specific device path.
  ///
  /// - Note: Currently supported on Linux.
  public static func microphone(devicePath: String) throws -> AudioSourceBuilder {
    #if os(Linux)
      return AudioSourceBuilder(selection: .devicePath(devicePath))
    #else
      throw AudioSourceError.devicePathUnsupported(devicePath)
    #endif
  }

  /// Convenience initializer for common cases.
  public static func microphone(
    sampleRate: Int,
    channels: Int,
    format: AudioFormat = .s16le,
    encoding: Encoding = .raw
  ) throws -> AudioSource {
    try microphone()
      .withSampleRate(sampleRate)
      .withChannels(channels)
      .withFormat(format)
      .withEncoding(encoding)
      .build()
  }

  private static func resolveDeviceSelection(forName name: String) throws
    -> AudioSourceBuilder.DeviceSelection
  {
    let monitor = DeviceMonitor()
    let devices = monitor.audioSources()
    let normalized = name.lowercased()

    for (index, device) in devices.enumerated() {
      if device.displayName.lowercased() == normalized {
        #if os(Linux)
          if let path = device.property("device.path")
            ?? device.property("api.alsa.path")
            ?? device.property("api.pulse.path")
            ?? device.property("api.pipewire.path")
          {
            return .devicePath(path)
          }
          return .deviceIndex(index)
        #else
          return .deviceIndex(index)
        #endif
      }
    }

    throw AudioSourceError.deviceNotFound(name)
  }

  private static func uniqueID(for device: Device, index: Int) -> String {
    if let path = device.property("device.path") {
      return path
    }
    if let path = device.property("api.alsa.path") {
      return path
    }
    if let path = device.property("api.pulse.path") {
      return path
    }
    if let path = device.property("api.pipewire.path") {
      return path
    }
    if let serial = device.property("device.serial") {
      return serial
    }
    if let uuid = device.property("device.uuid") {
      return uuid
    }
    return "device-\(index)"
  }

  private static func parseCapabilities(_ caps: String?) -> AudioDeviceInfo.Capabilities {
    guard let caps else {
      return AudioDeviceInfo.Capabilities(sampleRates: [], channels: [], formats: [])
    }

    let structures = caps.split(separator: ";")
    var sampleRates: [Int] = []
    var channels: [Int] = []
    var formats: [AudioFormat] = []

    for structure in structures {
      let components = structure.split(separator: ",")
      for component in components {
        let trimmed = component.trimmingWhitespace()
        guard let separator = trimmed.firstIndex(of: "=") else { continue }
        let key = trimmed[..<separator].trimmingWhitespace()
        let value = trimmed[trimmed.index(after: separator)...].trimmingWhitespace()
        let cleaned = stripTypeAnnotation(String(value))

        if key == "rate" {
          sampleRates.append(contentsOf: parseIntList(from: cleaned))
        } else if key == "channels" {
          channels.append(contentsOf: parseIntList(from: cleaned))
        } else if key == "format" {
          formats.append(contentsOf: parseAudioFormats(from: cleaned))
        }
      }
    }

    let uniqueRates = Array(Set(sampleRates)).sorted()
    let uniqueChannels = Array(Set(channels)).sorted()
    let uniqueFormats = Array(Set(formats))
      .sorted { $0.formatString < $1.formatString }

    return AudioDeviceInfo.Capabilities(
      sampleRates: uniqueRates,
      channels: uniqueChannels,
      formats: uniqueFormats
    )
  }
}

/// Builder for configuring an AudioSource pipeline.
public struct AudioSourceBuilder: Sendable {
  fileprivate enum DeviceSelection: Sendable {
    case deviceIndex(Int)
    case devicePath(String)
  }

  private let selection: DeviceSelection
  private var sampleRate: Int?
  private var channels: Int?
  private var format: AudioFormat?
  private var encoding: AudioSource.Encoding = .raw

  fileprivate init(selection: DeviceSelection) {
    self.selection = selection
  }

  /// Set the sample rate in Hz.
  public func withSampleRate(_ rate: Int) -> AudioSourceBuilder {
    var copy = self
    copy.sampleRate = rate
    return copy
  }

  /// Set the number of channels.
  public func withChannels(_ channels: Int) -> AudioSourceBuilder {
    var copy = self
    copy.channels = channels
    return copy
  }

  /// Set the sample format.
  public func withFormat(_ format: AudioFormat) -> AudioSourceBuilder {
    var copy = self
    copy.format = format
    return copy
  }

  /// Set output encoding.
  public func withEncoding(_ encoding: AudioSource.Encoding) -> AudioSourceBuilder {
    var copy = self
    copy.encoding = encoding
    return copy
  }

  /// Encode audio to Opus.
  public func withOpusEncoding(bitrate: Int) -> AudioSourceBuilder {
    withEncoding(.opus(bitrate: bitrate))
  }

  /// Encode audio to AAC.
  public func withAACEncoding(bitrate: Int) -> AudioSourceBuilder {
    withEncoding(.aac(bitrate: bitrate))
  }

  /// Build the AudioSource, selecting the first working pipeline.
  public func build() throws -> AudioSource {
    if let sampleRate, sampleRate <= 0 {
      throw AudioSource.AudioSourceError.invalidConfiguration("Sample rate must be positive")
    }

    if let channels, channels <= 0 {
      throw AudioSource.AudioSourceError.invalidConfiguration("Channels must be positive")
    }

    if case .opus(let bitrate) = encoding, bitrate <= 0 {
      throw AudioSource.AudioSourceError.invalidConfiguration("Opus bitrate must be positive")
    }

    if case .aac(let bitrate) = encoding, bitrate <= 0 {
      throw AudioSource.AudioSourceError.invalidConfiguration("AAC bitrate must be positive")
    }

    let sinkName = "sink\(UInt32.random(in: 0...UInt32.max))"

    let sourceCandidates = resolveSourceCandidates()
    let encoderCandidates = resolveEncoderCandidates()

    var diagnostics: [String] = []

    for source in sourceCandidates {
      for encoder in encoderCandidates {
        let description = buildPipelineDescription(
          source: source,
          encoder: encoder,
          sinkName: sinkName
        )

        do {
          let pipeline = try Pipeline(description)
          let audioSink: AudioSink?
          let packetSink: AudioPacketSink?

          if encoding == .raw {
            audioSink = try pipeline.audioSink(named: sinkName)
            packetSink = nil
          } else {
            audioSink = nil
            packetSink = try AudioPacketSink(pipeline: pipeline, name: sinkName)
          }

          do {
            try pipeline.play()
          } catch {
            pipeline.stop()
            throw error
          }

          return AudioSource(
            pipeline: pipeline,
            audioSink: audioSink,
            packetSink: packetSink,
            pipelineDescription: description,
            diagnostics: diagnostics,
            encoding: encoding
          )
        } catch {
          diagnostics.append("Failed: \(description) -> \(error)")
          continue
        }
      }
    }

    throw AudioSource.AudioSourceError.noWorkingPipeline(diagnostics)
  }

  private func resolveSourceCandidates() -> [String] {
    switch selection {
    case .deviceIndex(let index):
      var candidates: [String] = []

      #if os(macOS) || os(iOS)
        candidates.append("osxaudiosrc device=\(index)")
      #elseif os(Linux)
        candidates.append("alsasrc device=hw:\(index),0")
        candidates.append("pulsesrc")
        candidates.append("pipewiresrc")
      #endif

      if index == 0 {
        candidates.append("autoaudiosrc")
      }

      if candidates.isEmpty {
        candidates.append("autoaudiosrc")
      }

      return candidates

    case .devicePath(let path):
      #if os(Linux)
        var candidates: [String] = []

        if path.hasPrefix("hw:") || path.hasPrefix("plughw:") || path == "default" {
          candidates.append("alsasrc device=\(path)")
        } else {
          candidates.append("pulsesrc device=\(path)")
          candidates.append("pipewiresrc device=\(path)")
          candidates.append("alsasrc device=\(path)")
        }

        candidates.append("autoaudiosrc")
        return candidates
      #else
        return ["autoaudiosrc"]
      #endif
    }
  }

  private func resolveEncoderCandidates() -> [String?] {
    switch encoding {
    case .raw:
      return [nil]

    case .opus(let bitrate):
      return ["opusenc bitrate=\(bitrate)"]

    case .aac(let bitrate):
      return [
        "avenc_aac bitrate=\(bitrate)",
        "faac bitrate=\(bitrate)",
        "voaacenc bitrate=\(bitrate)",
      ].map { Optional($0) }
    }
  }

  private func buildPipelineDescription(
    source: String,
    encoder: String?,
    sinkName: String
  ) -> String {
    var parts: [String] = [source, "audioconvert", "audioresample"]

    let caps = buildCaps()
    if !caps.isEmpty {
      parts.append(caps)
    }

    if let encoder {
      parts.append(encoder)
    }

    parts.append("appsink name=\(sinkName) sync=false drop=true max-buffers=1 emit-signals=true")

    return parts.joined(separator: " ! ")
  }

  private func buildCaps() -> String {
    var builder = CapsBuilder.audio()

    if let format {
      builder = builder.format(format)
    } else if encoding != .raw {
      builder = builder.format(.s16le)
    }

    if let sampleRate {
      builder = builder.rate(sampleRate)
    } else if encoding != .raw {
      builder = builder.rate(48_000)
    }

    if let channels {
      builder = builder.channels(channels)
    } else if encoding != .raw {
      builder = builder.channels(2)
    }

    return builder.build()
  }
}

private final class AudioPacketSink: @unchecked Sendable {
  private let element: Element

  private var appSink: UnsafeMutablePointer<GstAppSink> {
    UnsafeMutableRawPointer(element.element).assumingMemoryBound(to: GstAppSink.self)
  }

  init(pipeline: Pipeline, name: String) throws {
    guard let element = pipeline.element(named: name) else {
      throw GStreamerError.elementNotFound(name)
    }
    self.element = element
  }

  struct Packets: AsyncSequence {
    let sink: AudioPacketSink

    struct AsyncIterator: AsyncIteratorProtocol {
      let sink: AudioPacketSink

      mutating func next() async -> Buffer? {
        while !Task.isCancelled {
          if let sample = swift_gst_app_sink_try_pull_sample(sink.appSink, 100_000_000) {
            defer { swift_gst_sample_unref(UnsafeMutableRawPointer(sample)) }

            guard let gstBuffer = swift_gst_sample_get_buffer(UnsafeMutableRawPointer(sample))
            else {
              continue
            }

            let bufferSize = swift_gst_buffer_get_size(gstBuffer)
            guard bufferSize > 0 else { continue }

            _ = swift_gst_buffer_ref(gstBuffer)

            return Buffer(buffer: gstBuffer, ownsReference: true)
          }

          if swift_gst_app_sink_is_eos(sink.appSink) != 0 {
            break
          }

          await Task.yield()
        }

        return nil
      }
    }

    func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(sink: sink)
    }
  }

  func packets() -> AsyncStream<Buffer> {
    AsyncStream { continuation in
      let task = Task.detached { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        var iterator = Packets(sink: self).makeAsyncIterator()
        while let packet = await iterator.next() {
          continuation.yield(packet)
        }
        continuation.finish()
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}

private func stripTypeAnnotation(_ value: String) -> String {
  let trimmed = value.trimmingWhitespace()
  if trimmed.hasPrefix("(") {
    if let closeIndex = trimmed.firstIndex(of: ")") {
      let remainder = trimmed[trimmed.index(after: closeIndex)...]
      return String(remainder.trimmingWhitespace())
    }
  }
  return trimmed
}

private func parseIntList(from value: String) -> [Int] {
  let trimmed = value.trimmingWhitespace()

  if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
    let inner = trimmed.dropFirst().dropLast()
    return inner.split(separator: ",").compactMap { Int($0.trimmingWhitespace()) }
  }

  return [Int(trimmed)].compactMap { $0 }
}

private func parseAudioFormats(from value: String) -> [AudioFormat] {
  let trimmed = value.trimmingWhitespace()

  if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
    let inner = trimmed.dropFirst().dropLast()
    return
      inner
      .split(separator: ",")
      .map { String($0.trimmingWhitespace()) }
      .filter { !$0.isEmpty }
      .map { AudioFormat(string: $0) }
  }

  return [AudioFormat(string: trimmed)]
}
