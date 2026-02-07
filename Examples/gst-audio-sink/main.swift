import Foundation
import GStreamer

/// Example showing the ergonomic AudioSink API by playing a sine tone.
@main
struct GstAudioSinkExample {
  static func main() async throws {
    print("GStreamer version: \(GStreamer.versionString)")

    let speakers = try AudioSink.availableSpeakers()
    if !speakers.isEmpty {
      print("Speakers:")
      for speaker in speakers {
        print("  [\(speaker.index)] \(speaker.name)")
      }
    }

    let sampleRate = 48_000
    let channels = 1

    let sink = try AudioSink.speaker(deviceIndex: speakers.first?.index ?? 0)
      .withSampleRate(sampleRate)
      .withChannels(channels)
      .withFormat(.s16le)
      .build()

    print("Selected pipeline:")
    print(sink.selectedPipeline)

    let frequency = 440.0
    let durationSeconds = 2.0
    let framesPerBuffer = 480  // 10ms at 48kHz
    let totalFrames = Int(durationSeconds * Double(sampleRate))
    let totalBuffers = totalFrames / framesPerBuffer
    let phaseIncrement = 2.0 * Double.pi * frequency / Double(sampleRate)
    var phase = 0.0

    let bufferDuration = UInt64(
      Double(framesPerBuffer) / Double(sampleRate) * 1_000_000_000.0
    )
    var pts: UInt64 = 0

    for _ in 0..<totalBuffers {
      var samples = [Int16](repeating: 0, count: framesPerBuffer * channels)
      for i in 0..<framesPerBuffer {
        let sample = sin(phase) * 0.2
        phase += phaseIncrement
        let clamped = max(-1.0, min(1.0, sample))
        let value = Int16(clamped * Double(Int16.max))
        for ch in 0..<channels {
          samples[i * channels + ch] = value
        }
      }

      let bytes = samples.withUnsafeBytes { Array($0) }
      try await sink.play(data: bytes, pts: pts, duration: bufferDuration)
      pts += bufferDuration
    }

    sink.finish()
    print("Finished playback.")

    await sink.stop()
  }
}
