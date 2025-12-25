import GStreamer

/// Example showing how to use AppSink to pull video frames.
@main
struct GstAppSinkExample {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        // Create a pipeline with appsink
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=10 ! \
            video/x-raw,format=BGRA,width=320,height=240 ! \
            appsink name=sink emit-signals=false max-buffers=1 drop=true
            """
        )

        // Get the appsink element
        let appSink = try AppSink(pipeline: pipeline, name: "sink")

        // Start the pipeline
        try pipeline.play()

        print("Pulling frames from pipeline...")

        var frameCount = 0
        for await frame in appSink.frames() {
            frameCount += 1

            print("Frame \(frameCount): \(frame.width)x\(frame.height) \(frame.format.formatString)")

            // Access the buffer data safely - the span cannot escape the closure
            try frame.withMappedBytes { span in
                span.withUnsafeBytes { buffer in
                    let firstBytes = Array(buffer.prefix(8))
                    print("  First bytes: \(firstBytes)")
                }
            }
        }

        print("Total frames received: \(frameCount)")

        // Stop the pipeline
        pipeline.stop()
    }
}
