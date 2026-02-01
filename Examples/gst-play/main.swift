import GStreamer

/// Simple example that plays a test video pattern.
@main
struct GstPlay {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        do {
            try await runPipeline {
                VideoTestSource(numberOfBuffers: 100)
                RawVideoFormat(width: 128, height: 128)
                #if os(macOS)
                OSXVideoSink()
                #else
                AutoVideoSink()
                #endif
            }
            print("Playback finished successfully")
        } catch {
            print("Pipeline error")
        }
    }
}
