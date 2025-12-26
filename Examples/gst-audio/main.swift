import GStreamer
import Foundation

/// Example showing audio capture with AudioSink.
///
/// Supports multiple audio backends:
/// - PipeWire (modern Linux: Fedora 34+, Ubuntu 22.10+)
/// - PulseAudio (traditional Linux)
/// - ALSA (low-level, always available on Linux)
@main
struct GstAudioExample {
    enum AudioBackend: String, CaseIterable {
        case pipewire = "pipewiresrc"
        case pulseaudio = "pulsesrc"
        case alsa = "alsasrc device=default"

        var displayName: String {
            switch self {
            case .pipewire: return "PipeWire"
            case .pulseaudio: return "PulseAudio"
            case .alsa: return "ALSA"
            }
        }
    }

    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        // Try backends in order of preference
        let backends: [AudioBackend] = [.pipewire, .pulseaudio, .alsa]

        for backend in backends {
            if await tryBackend(backend) {
                return
            }
        }

        print("No audio backend available. Install gstreamer plugins:")
        print("  PipeWire: gstreamer1.0-pipewire")
        print("  PulseAudio: gstreamer1.0-pulseaudio")
        print("  ALSA: gstreamer1.0-alsa")
    }

    static func tryBackend(_ backend: AudioBackend) async -> Bool {
        print("\nTrying \(backend.displayName)...")

        // Create pipeline for 16kHz mono audio (speech recognition format)
        let pipelineDesc = """
            \(backend.rawValue) ! \
            audioconvert ! \
            audioresample ! \
            audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
            appsink name=sink
            """

        do {
            let pipeline = try Pipeline(pipelineDesc)
            let sink = try pipeline.audioSink(named: "sink")
            try pipeline.play()

            print("\(backend.displayName) audio capture started")
            print("Format: 16kHz mono S16LE (speech recognition ready)")
            print("Capturing 3 seconds of audio...\n")

            var totalSamples = 0
            let targetSamples = 16000 * 3 // 3 seconds at 16kHz

            for await buffer in sink.buffers() {
                totalSamples += buffer.sampleCount

                // Calculate audio level (RMS)
                let level = try buffer.withMappedBytes { span -> Double in
                    var sum: Double = 0
                    span.withUnsafeBytes { bytes in
                        let samples = bytes.bindMemory(to: Int16.self)
                        for sample in samples {
                            let normalized = Double(sample) / 32768.0
                            sum += normalized * normalized
                        }
                    }
                    return sqrt(sum / Double(buffer.sampleCount))
                }

                // Display audio meter
                let bars = Int(level * 50)
                let meter = String(repeating: "=", count: min(bars, 50))
                let output = "\r[\(meter.padding(toLength: 50, withPad: " ", startingAt: 0))] \(String(format: "%.1f", Double(totalSamples) / 16000.0))s"
                FileHandle.standardOutput.write(Data(output.utf8))

                if totalSamples >= targetSamples {
                    break
                }
            }

            print("\n\nCapture complete!")
            print("Total samples: \(totalSamples)")
            print("Duration: \(String(format: "%.2f", Double(totalSamples) / 16000.0)) seconds")

            pipeline.stop()
            return true

        } catch {
            print("\(backend.displayName) not available: \(error)")
            return false
        }
    }
}
