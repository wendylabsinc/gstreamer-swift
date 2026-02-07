import CGStreamer
import CGStreamerApp
import CGStreamerShim

/// High-level audio playback API with device selection.
///
/// AudioOutput provides a builder for common speaker/headphone playback
/// pipelines. Audio is pushed via ``play(_:)`` using raw PCM buffers.
public final class AudioOutput: @unchecked Sendable {
  /// Errors that can occur when building an audio output.
  public enum AudioOutputError: Error, Sendable, CustomStringConvertible {
    case deviceNotFound(String)
    case devicePathUnsupported(String)
    case invalidConfiguration(String)
    case noWorkingPipeline([String])

    public var description: String {
      switch self {
      case .deviceNotFound(let name):
        return "No speaker found matching: \(name)"
      case .devicePathUnsupported(let path):
        return "Device path not supported on this platform: \(path)"
      case .invalidConfiguration(let message):
        return "Invalid AudioOutput configuration: \(message)"
      case .noWorkingPipeline(let diagnostics):
        if diagnostics.isEmpty {
          return "No working audio output pipeline found"
        }
        return "No working audio output pipeline found. Attempts:\n"
          + diagnostics.joined(separator: "\n")
      }
    }
  }

  private let pipeline: Pipeline
  private let source: AppSource
  private let pipelineDescription: String
  private let buildDiagnostics: [String]

  internal init(
    pipeline: Pipeline,
    source: AppSource,
    pipelineDescription: String,
    diagnostics: [String]
  ) {
    self.pipeline = pipeline
    self.source = source
    self.pipelineDescription = pipelineDescription
    self.buildDiagnostics = diagnostics
  }

  deinit {
    pipeline.stop()
  }

  /// The selected pipeline description used to build this output.
  public var selectedPipeline: String {
    pipelineDescription
  }

  /// Diagnostics from pipeline selection and fallback attempts.
  public var diagnostics: [String] {
    buildDiagnostics
  }

  /// Push an audio buffer to the output.
  public func play(_ buffer: AudioBuffer) async throws {
    try source.push(data: buffer.bytes, pts: buffer.pts, duration: buffer.duration)
  }

  /// Push an audio packet from a raw buffer.
  public func play(_ buffer: Buffer) async throws {
    try source.push(data: buffer.bytes, pts: buffer.pts, duration: buffer.duration)
  }

  /// Push raw audio bytes to the output.
  public func play(data: [UInt8], pts: UInt64? = nil, duration: UInt64? = nil) async throws {
    try source.push(data: data, pts: pts, duration: duration)
  }

  /// Signal end-of-stream to the output.
  public func finish() {
    source.endOfStream()
  }

  /// Stop the underlying pipeline.
  public func stop() async {
    pipeline.stop()
  }

  /// Discover available speaker/output devices on the system.
  public static func availableSpeakers() throws -> [AudioDeviceInfo] {
    let monitor = DeviceMonitor()
    let devices = monitor.audioSinks()

    return devices.enumerated().map { index, device in
      let uniqueID = AudioOutput.uniqueID(for: device, index: index)
      let capabilities = AudioOutput.parseCapabilities(device.caps)
      return AudioDeviceInfo(
        index: index,
        name: device.displayName,
        uniqueID: uniqueID,
        type: .output,
        capabilities: capabilities
      )
    }
  }

  /// Create an audio output using the default device (typically index 0).
  public static func speaker(deviceIndex: Int = 0) -> AudioOutputBuilder {
    AudioOutputBuilder(selection: .deviceIndex(deviceIndex))
  }

  /// Create an audio output by matching a device display name.
  public static func speaker(name: String) throws -> AudioOutputBuilder {
    let resolved = try resolveDeviceSelection(forName: name)
    return AudioOutputBuilder(selection: resolved)
  }

  /// Create an audio output using a platform-specific device path.
  ///
  /// - Note: Currently supported on Linux.
  public static func speaker(devicePath: String) throws -> AudioOutputBuilder {
    #if os(Linux)
      return AudioOutputBuilder(selection: .devicePath(devicePath))
    #else
      throw AudioOutputError.devicePathUnsupported(devicePath)
    #endif
  }

  /// Convenience initializer for common cases.
  public static func speaker(
    sampleRate: Int,
    channels: Int,
    format: AudioFormat = .s16le
  ) throws -> AudioOutput {
    try speaker()
      .withSampleRate(sampleRate)
      .withChannels(channels)
      .withFormat(format)
      .build()
  }

  private static func resolveDeviceSelection(forName name: String) throws
    -> AudioOutputBuilder.DeviceSelection
  {
    let monitor = DeviceMonitor()
    let devices = monitor.audioSinks()
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

    throw AudioOutputError.deviceNotFound(name)
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

/// Builder for configuring an AudioOutput pipeline.
public struct AudioOutputBuilder: Sendable {
  fileprivate enum DeviceSelection: Sendable {
    case deviceIndex(Int)
    case devicePath(String)
  }

  private let selection: DeviceSelection
  private var sampleRate: Int?
  private var channels: Int?
  private var format: AudioFormat?

  fileprivate init(selection: DeviceSelection) {
    self.selection = selection
  }

  /// Set the sample rate in Hz.
  public func withSampleRate(_ rate: Int) -> AudioOutputBuilder {
    var copy = self
    copy.sampleRate = rate
    return copy
  }

  /// Set the number of channels.
  public func withChannels(_ channels: Int) -> AudioOutputBuilder {
    var copy = self
    copy.channels = channels
    return copy
  }

  /// Set the sample format.
  public func withFormat(_ format: AudioFormat) -> AudioOutputBuilder {
    var copy = self
    copy.format = format
    return copy
  }

  /// Build the AudioOutput, selecting the first working pipeline.
  public func build() throws -> AudioOutput {
    if let sampleRate, sampleRate <= 0 {
      throw AudioOutput.AudioOutputError.invalidConfiguration("Sample rate must be positive")
    }

    if let channels, channels <= 0 {
      throw AudioOutput.AudioOutputError.invalidConfiguration("Channels must be positive")
    }

    let sourceName = "src\(UInt32.random(in: 0...UInt32.max))"

    let sinkCandidates = resolveSinkCandidates()

    var diagnostics: [String] = []

    for sink in sinkCandidates {
      let description = buildPipelineDescription(sourceName: sourceName, sink: sink)

      do {
        let pipeline = try Pipeline(description)
        let appSource = try pipeline.appSource(named: sourceName)

        appSource.setCaps(buildCaps())
        appSource.setLive(true)
        appSource.setStreamType(.stream)

        do {
          try pipeline.play()
        } catch {
          pipeline.stop()
          throw error
        }

        return AudioOutput(
          pipeline: pipeline,
          source: appSource,
          pipelineDescription: description,
          diagnostics: diagnostics
        )
      } catch {
        diagnostics.append("Failed: \(description) -> \(error)")
        continue
      }
    }

    throw AudioOutput.AudioOutputError.noWorkingPipeline(diagnostics)
  }

  private func resolveSinkCandidates() -> [String] {
    switch selection {
    case .deviceIndex(let index):
      var candidates: [String] = []

      #if os(macOS) || os(iOS)
        candidates.append("osxaudiosink device=\(index)")
      #elseif os(Linux)
        candidates.append("alsasink device=hw:\(index),0")
        candidates.append("pulsesink")
        candidates.append("pipewiresink")
      #endif

      if index == 0 {
        candidates.append("autoaudiosink")
      }

      if candidates.isEmpty {
        candidates.append("autoaudiosink")
      }

      return candidates

    case .devicePath(let path):
      #if os(Linux)
        var candidates: [String] = []

        if path.hasPrefix("hw:") || path.hasPrefix("plughw:") || path == "default" {
          candidates.append("alsasink device=\(path)")
        } else {
          candidates.append("pulsesink device=\(path)")
          candidates.append("pipewiresink device=\(path)")
          candidates.append("alsasink device=\(path)")
        }

        candidates.append("autoaudiosink")
        return candidates
      #else
        return ["autoaudiosink"]
      #endif
    }
  }

  private func buildPipelineDescription(sourceName: String, sink: String) -> String {
    [
      "appsrc name=\(sourceName) is-live=true format=time",
      "audioconvert",
      "audioresample",
      buildCaps(),
      sink,
    ].joined(separator: " ! ")
  }

  private func buildCaps() -> String {
    var builder = CapsBuilder.audio()

    if let format {
      builder = builder.format(format)
    } else {
      builder = builder.format(.s16le)
    }

    if let sampleRate {
      builder = builder.rate(sampleRate)
    }

    if let channels {
      builder = builder.channels(channels)
    }

    return builder.build()
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
