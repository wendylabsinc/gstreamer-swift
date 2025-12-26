import GStreamer

/// Simple example that plays a test video pattern.
@main
struct GstPlay {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        do {
            try await runPipeline {
                URIDecodeSource(uri: "rtsp://joannis:wendylabs@192.168.0.112:554/stream1")
                VideoScale()
                VideoConvert()
                // VideoTestSource(numberOfBuffers: 100)
                // RawVideoFormat(width: 128, height: 128)
                OSXVideoSink()
            }
            print("Playback finished successfully")
        } catch {
            print("Pipeline error")
        }
    }
}
