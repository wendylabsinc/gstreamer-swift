import GStreamer
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Terminal audio visualizer using GStreamer.
@main
struct AudioVisualizer {
    static func main() async throws {
        let barCount = 32
        let barHeight = 10

        // Use audioconvert + audioresample to handle format conversion from mic
        let pipeline = try Pipeline(
            """
            autoaudiosrc ! \
            audioconvert ! \
            audioresample ! \
            audio/x-raw,format=S16LE,rate=44100,channels=1 ! \
            appsink name=sink emit-signals=false max-buffers=2 drop=true sync=false
            """
        )

        let audioSink = try AudioSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        // Small delay to let pipeline start
        try await Task.sleep(for: .milliseconds(100))

        // Alternate screen + hide cursor
        print("\u{001B}[?1049h\u{001B}[?25l", terminator: "")

        defer {
            print("\u{001B}[?25h\u{001B}[?1049l")
            pipeline.stop()
        }

        var frame = 0
        for await buffer in audioSink.buffers() {
            frame += 1
            let levels = computeLevels(buffer: buffer, bands: barCount)

            // Home cursor
            print("\u{001B}[H", terminator: "")

            // Render bars
            for row in (0..<barHeight).reversed() {
                let thresh = Float(row) / Float(barHeight)
                for level in levels {
                    let norm = min(1.0, level * 4)
                    if norm > thresh {
                        let c = row >= barHeight * 2/3 ? "91" : row >= barHeight/3 ? "93" : "92"
                        print("\u{001B}[\(c)m█\u{001B}[0m", terminator: "")
                    } else {
                        print(" ", terminator: "")
                    }
                }
                print()
            }
            print(String(repeating: "─", count: barCount))
            print("Frame \(frame) | Peak: \(String(format: "%.2f", levels.max() ?? 0))  [Ctrl+C to exit]")
        }
    }

    static func computeLevels(buffer: AudioBuffer, bands: Int) -> [Float] {
        var out = [Float](repeating: 0, count: bands)
        buffer.bytes.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            guard samples.count > 0 else { return }
            let perBand = max(1, samples.count / bands)
            for b in 0..<bands {
                var e: Float = 0
                let s = b * perBand, end = min(s + perBand, samples.count)
                for i in s..<end {
                    let v = Float(samples[i]) / 32768
                    e += v * v
                }
                out[b] = sqrt(e / Float(end - s))
            }
        }
        return out
    }
}
