/// High-level webcam capture API with automatic source selection and fallback.
///
/// VideoSource provides a fluent builder for common camera capture pipelines,
/// including resolution, framerate, aspect ratio handling, and optional encoding.
///
/// ## Example
///
/// ```swift
/// let source = try VideoSource.webcam()
///     .withResolution(.hd720p)
///     .withFramerate(30)
///     .withJPEGEncoding(quality: 85)
///     .preferHardwareAcceleration()
///     .build()
///
/// for try await frame in source.frames() {
///     // Encoded bytes are available via frame.bytes
/// }
/// ```
public final class VideoSource: @unchecked Sendable {
  /// Available webcam information.
  public struct WebcamInfo: Sendable, Hashable {
    public let index: Int
    public let name: String
    public let uniqueID: String
    public let capabilities: [Capability]

    public struct Capability: Sendable, Hashable {
      public let width: Int
      public let height: Int
      public let framerates: [Int]
      public let formats: [String]

      public init(width: Int, height: Int, framerates: [Int], formats: [String]) {
        self.width = width
        self.height = height
        self.framerates = framerates
        self.formats = formats
      }
    }

    public init(index: Int, name: String, uniqueID: String, capabilities: [Capability]) {
      self.index = index
      self.name = name
      self.uniqueID = uniqueID
      self.capabilities = capabilities
    }
  }

  /// Common resolution presets.
  public enum Resolution: Sendable, Hashable {
    case vga
    case hd720p
    case hd1080p
    case custom(width: Int, height: Int)

    var size: (width: Int, height: Int) {
      switch self {
      case .vga:
        return (640, 480)
      case .hd720p:
        return (1280, 720)
      case .hd1080p:
        return (1920, 1080)
      case .custom(let width, let height):
        return (width, height)
      }
    }
  }

  /// Aspect ratio handling for scaling.
  public enum AspectRatio: Sendable, Hashable {
    case original
    case fourByThree
    case sixteenByNine
    case custom(width: Int, height: Int)

    var ratio: (numerator: Int, denominator: Int)? {
      switch self {
      case .original:
        return nil
      case .fourByThree:
        return (4, 3)
      case .sixteenByNine:
        return (16, 9)
      case .custom(let width, let height):
        return (width, height)
      }
    }

    var ratioString: String? {
      guard let ratio else { return nil }
      return "\(ratio.numerator)/\(ratio.denominator)"
    }
  }

  /// Output encoding for video frames.
  public enum Encoding: Sendable, Hashable {
    case raw
    case jpeg(quality: Int)
    case h264(bitrate: Int)
  }

  /// Errors that can occur when building a video source.
  public enum VideoSourceError: Error, Sendable, CustomStringConvertible {
    case deviceNotFound(String)
    case devicePathUnsupported(String)
    case invalidConfiguration(String)
    case noWorkingPipeline([String])

    public var description: String {
      switch self {
      case .deviceNotFound(let name):
        return "No webcam found matching: \(name)"
      case .devicePathUnsupported(let path):
        return "Device path not supported on this platform: \(path)"
      case .invalidConfiguration(let message):
        return "Invalid VideoSource configuration: \(message)"
      case .noWorkingPipeline(let diagnostics):
        if diagnostics.isEmpty {
          return "No working pipeline found"
        }
        return "No working pipeline found. Attempts:\n" + diagnostics.joined(separator: "\n")
      }
    }
  }

  private let pipeline: Pipeline
  private let sink: AppSink
  private let pipelineDescription: String
  private let buildDiagnostics: [String]

  /// The encoding configured for this source.
  public let encoding: Encoding

  internal init(
    pipeline: Pipeline,
    sink: AppSink,
    pipelineDescription: String,
    diagnostics: [String],
    encoding: Encoding
  ) {
    self.pipeline = pipeline
    self.sink = sink
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

  /// An async sequence of video frames from this source.
  ///
  /// When encoding is `.raw`, frames contain raw pixel data (typically BGRA).
  /// For encoded outputs (`.jpeg`, `.h264`), frames contain encoded bytes and
  /// the frame format will be `.unknown`.
  public func frames() -> AppSink.Frames {
    sink.frames()
  }

  /// Stop the underlying pipeline.
  public func stop() async {
    pipeline.stop()
  }

  /// Discover available webcams on the system.
  public static func availableWebcams() throws -> [WebcamInfo] {
    let monitor = DeviceMonitor()
    let devices = monitor.videoSources()

    return devices.enumerated().map { index, device in
      let uniqueID = VideoSource.uniqueID(for: device, index: index)
      let capabilities = VideoSource.parseCapabilities(device.caps)
      return WebcamInfo(
        index: index,
        name: device.displayName,
        uniqueID: uniqueID,
        capabilities: capabilities
      )
    }
  }

  /// Create a webcam source using the default device (typically index 0).
  public static func webcam(deviceIndex: Int = 0) -> VideoSourceBuilder {
    VideoSourceBuilder(selection: .deviceIndex(deviceIndex))
  }

  /// Create a synthetic test pattern source (useful for tests or demos).
  public static func testPattern() -> VideoSourceBuilder {
    VideoSourceBuilder(selection: .testPattern)
  }

  /// Create a webcam source by matching a device display name.
  public static func webcam(name: String) throws -> VideoSourceBuilder {
    let resolved = try resolveDeviceSelection(forName: name)
    return VideoSourceBuilder(selection: resolved)
  }

  /// Create a webcam source using a platform-specific device path.
  ///
  /// - Note: Currently supported on Linux (`/dev/videoN`).
  public static func webcam(devicePath: String) throws -> VideoSourceBuilder {
    #if os(Linux)
      return VideoSourceBuilder(selection: .devicePath(devicePath))
    #else
      throw VideoSourceError.devicePathUnsupported(devicePath)
    #endif
  }

  /// Convenience initializer for common cases.
  public static func webcam(
    resolution: Resolution,
    encoding: Encoding = .raw
  ) throws -> VideoSource {
    try webcam()
      .withResolution(resolution)
      .withEncoding(encoding)
      .build()
  }

  private static func resolveDeviceSelection(forName name: String) throws
    -> VideoSourceBuilder.DeviceSelection
  {
    let monitor = DeviceMonitor()
    let devices = monitor.videoSources()
    let normalized = name.lowercased()

    for (index, device) in devices.enumerated() {
      if device.displayName.lowercased() == normalized {
        #if os(Linux)
          if let path = device.property("device.path") ?? device.property("api.v4l2.path") {
            return .devicePath(path)
          }
          return .deviceIndex(index)
        #else
          return .deviceIndex(index)
        #endif
      }
    }

    throw VideoSourceError.deviceNotFound(name)
  }

  private static func uniqueID(for device: Device, index: Int) -> String {
    if let path = device.property("device.path") {
      return path
    }
    if let path = device.property("api.v4l2.path") {
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

  private static func parseCapabilities(_ caps: String?) -> [WebcamInfo.Capability] {
    guard let caps else { return [] }
    let structures = caps.split(separator: ";")
    var capabilities: [WebcamInfo.Capability] = []

    for structure in structures {
      let components = structure.split(separator: ",")
      var width: Int?
      var height: Int?
      var framerates: [Int] = []
      var formats: [String] = []

      for component in components {
        let trimmed = component.trimmingWhitespace()
        guard let separator = trimmed.firstIndex(of: "=") else { continue }
        let key = trimmed[..<separator].trimmingWhitespace()
        let value = trimmed[trimmed.index(after: separator)...].trimmingWhitespace()
        let cleaned = stripTypeAnnotation(String(value))

        if key == "width" {
          width = parseFirstInt(from: cleaned)
        } else if key == "height" {
          height = parseFirstInt(from: cleaned)
        } else if key == "framerate" {
          framerates.append(contentsOf: parseFramerates(from: cleaned))
        } else if key == "format" {
          formats.append(contentsOf: parseStringList(from: cleaned))
        }
      }

      guard let width, let height else { continue }

      let uniqueFormats = Array(Set(formats)).sorted()
      let uniqueFramerates = Array(Set(framerates)).sorted()

      capabilities.append(
        WebcamInfo.Capability(
          width: width,
          height: height,
          framerates: uniqueFramerates,
          formats: uniqueFormats
        )
      )
    }

    return capabilities
  }
}

/// Builder for configuring a VideoSource pipeline.
public struct VideoSourceBuilder: Sendable {
  fileprivate enum DeviceSelection: Sendable {
    case deviceIndex(Int)
    case devicePath(String)
    case testPattern
  }

  fileprivate enum AspectMode: Sendable {
    case none
    case crop
    case letterbox
  }

  private let selection: DeviceSelection
  private var resolution: VideoSource.Resolution?
  private var framerate: Int?
  private var aspectRatio: VideoSource.AspectRatio?
  private var cropIfNeeded: Bool = false
  private var encoding: VideoSource.Encoding = .raw
  private var preferHardwareAcceleration: Bool = false

  fileprivate init(selection: DeviceSelection) {
    self.selection = selection
  }

  /// Set the output resolution.
  public func withResolution(_ resolution: VideoSource.Resolution) -> VideoSourceBuilder {
    var copy = self
    copy.resolution = resolution
    return copy
  }

  /// Set the output resolution with explicit dimensions.
  public func withResolution(width: Int, height: Int) -> VideoSourceBuilder {
    withResolution(.custom(width: width, height: height))
  }

  /// Set the target framerate in frames per second.
  public func withFramerate(_ fps: Int) -> VideoSourceBuilder {
    var copy = self
    copy.framerate = fps
    return copy
  }

  /// Configure aspect ratio handling.
  public func withAspectRatio(_ ratio: VideoSource.AspectRatio, cropIfNeeded: Bool)
    -> VideoSourceBuilder
  {
    var copy = self
    copy.aspectRatio = ratio
    copy.cropIfNeeded = cropIfNeeded
    return copy
  }

  /// Set output encoding.
  public func withEncoding(_ encoding: VideoSource.Encoding) -> VideoSourceBuilder {
    var copy = self
    copy.encoding = encoding
    return copy
  }

  /// Encode frames as JPEG.
  public func withJPEGEncoding(quality: Int) -> VideoSourceBuilder {
    withEncoding(.jpeg(quality: quality))
  }

  /// Encode frames as H.264 with target bitrate (in kbps).
  public func withH264Encoding(bitrate: Int) -> VideoSourceBuilder {
    withEncoding(.h264(bitrate: bitrate))
  }

  /// Prefer hardware-accelerated encoders when available.
  public func preferHardwareAcceleration(_ prefer: Bool = true) -> VideoSourceBuilder {
    var copy = self
    copy.preferHardwareAcceleration = prefer
    return copy
  }

  /// Build the VideoSource, selecting the first working pipeline.
  public func build() throws -> VideoSource {
    if let framerate, framerate <= 0 {
      throw VideoSource.VideoSourceError.invalidConfiguration("Framerate must be positive")
    }

    if let resolution {
      let size = resolution.size
      if size.width <= 0 || size.height <= 0 {
        throw VideoSource.VideoSourceError.invalidConfiguration("Resolution must be positive")
      }
    }

    if case .h264(let bitrate) = encoding, bitrate <= 0 {
      throw VideoSource.VideoSourceError.invalidConfiguration("H.264 bitrate must be positive")
    }

    let sinkName = "sink\(UInt32.random(in: 0...UInt32.max))"

    let sourceCandidates = try resolveSourceCandidates()
    let encoderCandidates = resolveEncoderCandidates()
    let aspectModes = resolveAspectModes()

    var diagnostics: [String] = []

    for source in sourceCandidates {
      for aspectMode in aspectModes {
        for encoder in encoderCandidates {
          let description = buildPipelineDescription(
            source: source,
            aspectMode: aspectMode,
            encoder: encoder,
            sinkName: sinkName
          )

          do {
            let pipeline = try Pipeline(description)
            let sink = try pipeline.appSink(named: sinkName)
            do {
              try pipeline.play()
            } catch {
              pipeline.stop()
              throw error
            }
            return VideoSource(
              pipeline: pipeline,
              sink: sink,
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
    }

    throw VideoSource.VideoSourceError.noWorkingPipeline(diagnostics)
  }

  private func resolveSourceCandidates() throws -> [String] {
    switch selection {
    case .deviceIndex(let index):
      var candidates: [String] = []

      #if os(macOS) || os(iOS)
        candidates.append("avfvideosrc device-index=\(index)")
      #elseif os(Linux)
        candidates.append("v4l2src device=/dev/video\(index)")
      #endif

      if index == 0 {
        candidates.append("autovideosrc")
      }

      if candidates.isEmpty {
        candidates.append("autovideosrc")
      }

      return candidates

    case .devicePath(let path):
      #if os(Linux)
        return ["v4l2src device=\(path)"]
      #else
        throw VideoSource.VideoSourceError.devicePathUnsupported(path)
      #endif
    case .testPattern:
      return ["videotestsrc is-live=true"]
    }
  }

  private func resolveEncoderCandidates() -> [String?] {
    switch encoding {
    case .raw:
      return [nil]

    case .jpeg(let quality):
      let clampedQuality = max(0, min(100, quality))
      var encoders: [String] = []
      if preferHardwareAcceleration {
        encoders.append("nvjpegenc quality=\(clampedQuality)")
        encoders.append("vaapijpegenc quality=\(clampedQuality)")
      }
      encoders.append("jpegenc quality=\(clampedQuality)")
      return encoders.map { Optional($0) }

    case .h264(let bitrate):
      var encoders: [String] = []
      if preferHardwareAcceleration {
        #if os(macOS) || os(iOS)
          encoders.append("vtenc_h264 bitrate=\(bitrate)")
        #endif
        encoders.append("nvh264enc bitrate=\(bitrate)")
        encoders.append("vaapih264enc bitrate=\(bitrate)")
      }
      encoders.append("x264enc bitrate=\(bitrate) speed-preset=veryfast tune=zerolatency")
      return encoders.map { Optional($0) }
    }
  }

  private func resolveAspectModes() -> [AspectMode] {
    guard let ratio = aspectRatio, ratio != .original else {
      return [.none]
    }

    if cropIfNeeded {
      return [.crop, .letterbox]
    }

    return [.letterbox]
  }

  private func buildPipelineDescription(
    source: String,
    aspectMode: AspectMode,
    encoder: String?,
    sinkName: String
  ) -> String {
    var parts: [String] = [source, "videoconvert"]

    if let aspectRatio, let ratioString = aspectRatio.ratioString, aspectMode == .crop {
      parts.append("aspectratiocrop aspect-ratio=\(ratioString)")
    }

    var videoscale = "videoscale"
    if aspectMode == .letterbox {
      videoscale += " add-borders=true"
    }
    parts.append(videoscale)

    if let framerate, framerate > 0 {
      parts.append("videorate")
    }

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
    var builder = CapsBuilder.video()

    if encoding == .raw {
      builder = builder.format(.bgra)
    }

    if let resolution {
      let size = resolution.size
      builder = builder.size(width: size.width, height: size.height)
    }

    if let framerate, framerate > 0 {
      builder = builder.framerate(framerate, 1)
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

private func parseFirstInt(from value: String) -> Int? {
  let tokens = value.split(whereSeparator: { !$0.isNumber })
  return tokens.compactMap { Int($0) }.first
}

private func parseFramerates(from value: String) -> [Int] {
  let tokens = value.split(whereSeparator: { !($0.isNumber || $0 == "/") })
  var results: [Int] = []

  for token in tokens {
    let parts = token.split(separator: "/")
    if parts.count == 2,
      let numerator = Int(parts[0]),
      let denominator = Int(parts[1]),
      denominator > 0
    {
      results.append(numerator / denominator)
    } else if parts.count == 1, let number = Int(parts[0]) {
      results.append(number)
    }
  }

  return results
}

private func parseStringList(from value: String) -> [String] {
  let trimmed = value.trimmingWhitespace()

  if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
    let inner = trimmed.dropFirst().dropLast()
    return inner.split(separator: ",").map { String($0.trimmingWhitespace()) }.filter {
      !$0.isEmpty
    }
  }

  return [trimmed].filter { !$0.isEmpty }
}
