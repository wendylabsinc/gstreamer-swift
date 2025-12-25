import GStreamer

/// Simple example that plays a test video pattern.
@main
struct GstPlay {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        // Create a simple test pipeline
        let pipeline = try Pipeline("videotestsrc num-buffers=100 ! autovideosink")

        // Start playing
        try pipeline.play()

        // Listen for bus messages
        for await message in pipeline.bus.messages(filter: [.eos, .error]) {
            switch message {
            case .eos:
                print("Playback finished successfully")
            case .error(let message, let debug):
                print("Pipeline error: \(message)")
                if let debug { print("Debug: \(debug)") }
            default:
                break
            }
        }

        // Stop the pipeline
        pipeline.stop()
    }
}
