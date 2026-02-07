import GStreamer

/// Example showing the ergonomic AudioSource API with encoding fallback.
@main
struct GstAudioSourceExample {
  static func main() async throws {
    print("GStreamer version: \(GStreamer.versionString)")

    let microphones = try AudioSource.availableMicrophones()
    if microphones.isEmpty {
      print("No microphones found.")
      return
    }

    print("Microphones:")
    for mic in microphones {
      print("  [\(mic.index)] \(mic.name)")
    }

    let builder = AudioSource.microphone(deviceIndex: microphones[0].index)
      .withSampleRate(48_000)
      .withChannels(1)
      .withFormat(.s16le)

    let source: AudioSource
    do {
      source = try builder.withOpusEncoding(bitrate: 64_000).build()
      print("Encoding: Opus (64 kbps)")
    } catch {
      print("Opus encoding unavailable, falling back to raw: \(error)")
      source = try builder.withEncoding(.raw).build()
    }

    print("Selected pipeline:")
    print(source.selectedPipeline)

    switch source.encoding {
    case .raw:
      print("Capturing raw audio for 3 seconds...")
      let targetSamples = 48_000 * 3
      var totalSamples = 0
      for await buffer in source.buffers() {
        totalSamples += buffer.sampleCount
        if totalSamples >= targetSamples {
          break
        }
      }
      print("Captured \(totalSamples) samples")
    case .opus, .aac:
      print("Capturing 50 encoded packets...")
      var count = 0
      var totalBytes = 0
      for await packet in source.packets() {
        count += 1
        totalBytes += packet.bytes.byteCount
        if count >= 50 {
          break
        }
      }
      print("Captured \(count) packets (\(totalBytes) bytes)")
    }

    await source.stop()
  }
}
