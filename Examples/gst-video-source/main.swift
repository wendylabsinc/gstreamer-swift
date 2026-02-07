import GStreamer

/// Example showing the ergonomic VideoSource API.
@main
struct GstVideoSourceExample {
  static func main() async throws {
    print("GStreamer version: \(GStreamer.versionString)")

    let webcams = try VideoSource.availableWebcams()
    if webcams.isEmpty {
      print("No webcams found, using test pattern source.")
    } else {
      print("Webcams:")
      for webcam in webcams {
        print("  [\(webcam.index)] \(webcam.name)")
      }
    }

    let baseBuilder: VideoSourceBuilder
    if let first = webcams.first {
      print("Using webcam: \(first.name)")
      baseBuilder = VideoSource.webcam(deviceIndex: first.index)
    } else {
      baseBuilder = VideoSource.testPattern()
    }

    let configured =
      baseBuilder
      .withResolution(.hd720p)
      .withFramerate(30)
      .withAspectRatio(.sixteenByNine, cropIfNeeded: true)
      .preferHardwareAcceleration()

    try await runCapture(with: configured)
  }

  private static func runCapture(with builder: VideoSourceBuilder) async throws {
    let source = try buildSource(with: builder)
    let encoding = source.encoding
    print("Selected pipeline:")
    print(source.selectedPipeline)

    print("Encoding: \(encoding)")
    print("Capturing up to 30 frames...")

    let iterator = source.frames().makeAsyncIterator()
    var count = 0
    while count < 30 {
      guard (try await iterator.next()) != nil else {
        break
      }
      count += 1
      if count % 10 == 0 {
        print("Captured \(count) \(encoding == .raw ? "frames" : "packets")...")
      }
    }

    if count == 0 {
      print("No frames received.")
    } else {
      print("Capture complete: \(count) \(encoding == .raw ? "frames" : "packets").")
    }

    await source.stop()
  }

  private static func buildSource(with builder: VideoSourceBuilder) throws -> VideoSource {
    do {
      let source = try builder.withJPEGEncoding(quality: 85).build()
      print("Encoding: JPEG (quality 85)")
      return source
    } catch {
      print("JPEG encoding unavailable, falling back to raw: \(error)")
      return try builder.withEncoding(.raw).build()
    }
  }
}
