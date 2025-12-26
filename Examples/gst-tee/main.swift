import GStreamer

/// Example showing multi-output pipeline with Tee.
///
/// Demonstrates splitting a video stream to:
/// - Display (autovideosink)
/// - ML inference (appsink for frame processing)
///
/// This pattern is common for:
/// - Display + recording
/// - Display + ML inference
/// - Display + streaming
@main
struct GstTeeExample {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        // Pipeline with tee splitting to display and appsink
        // - Branch 1: Display (autovideosink)
        // - Branch 2: ML processing (appsink)
        let pipeline = try Pipeline("""
            videotestsrc num-buffers=100 ! \
            video/x-raw,format=BGRA,width=320,height=240,framerate=30/1 ! \
            tee name=t \
            t. ! queue ! autovideosink \
            t. ! queue ! appsink name=ml_sink emit-signals=false max-buffers=1 drop=true
            """)

        let mlSink = try pipeline.appSink(named: "ml_sink")

        try pipeline.play()
        print("Pipeline started with two branches:")
        print("  1. Display (autovideosink)")
        print("  2. ML processing (appsink)")
        print("\nProcessing frames for 'inference'...\n")

        var frameCount = 0
        var totalBrightness: Double = 0

        for await frame in mlSink.frames() {
            frameCount += 1

            // Simulate ML inference by calculating average brightness
            let brightness = try frame.withMappedBytes { span -> Double in
                var sum: UInt64 = 0
                span.withUnsafeBytes { bytes in
                    // BGRA format: calculate luminance from RGB
                    let pixels = bytes.bindMemory(to: UInt8.self)
                    for i in stride(from: 0, to: pixels.count, by: 4) {
                        let b = UInt64(pixels[i])
                        let g = UInt64(pixels[i + 1])
                        let r = UInt64(pixels[i + 2])
                        // Standard luminance formula
                        sum += (r * 299 + g * 587 + b * 114) / 1000
                    }
                }
                let pixelCount = frame.width * frame.height
                return Double(sum) / Double(pixelCount) / 255.0
            }

            totalBrightness += brightness

            // Print every 10th frame
            if frameCount % 10 == 0 {
                let bar = String(repeating: "=", count: Int(brightness * 30))
                print("Frame \(String(format: "%3d", frameCount)): brightness \(String(format: "%.2f", brightness)) [\(bar.padding(toLength: 30, withPad: " ", startingAt: 0))]")
            }
        }

        let avgBrightness = totalBrightness / Double(frameCount)
        print("\n" + String(repeating: "=", count: 50))
        print("Processing complete!")
        print("Total frames: \(frameCount)")
        print("Average brightness: \(String(format: "%.3f", avgBrightness))")

        pipeline.stop()
    }
}
