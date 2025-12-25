#if canImport(Vision)
import GStreamer
import Vision
import CoreImage

/// Example showing GStreamer + Vision framework integration (macOS/iOS).
///
/// Demonstrates:
/// - Converting VideoFrame to CVPixelBuffer
/// - Running Vision face detection on video frames
/// - Processing results in real-time
@main
struct GstVisionExample {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        // Create pipeline with test video
        // Using a pattern with moving elements for detection variety
        let pipeline = try Pipeline("""
            videotestsrc pattern=ball num-buffers=100 ! \
            video/x-raw,format=BGRA,width=640,height=480,framerate=30/1 ! \
            appsink name=sink emit-signals=false max-buffers=1 drop=true
            """)

        let sink = try pipeline.appSink(named: "sink")
        try pipeline.play()

        print("Running Vision rectangle detection on video frames...")
        print("(Using test pattern - try with webcam for face detection)\n")

        // Create rectangle detection request
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumConfidence = 0.5
        rectangleRequest.maximumObservations = 10

        var frameCount = 0
        var detectionsTotal = 0

        for await frame in sink.frames() {
            frameCount += 1

            // Convert to CVPixelBuffer for Vision
            guard let pixelBuffer = try frame.toCVPixelBuffer() else {
                print("Frame \(frameCount): Failed to create CVPixelBuffer")
                continue
            }

            // Run Vision detection
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

            do {
                try handler.perform([rectangleRequest])

                if let results = rectangleRequest.results, !results.isEmpty {
                    detectionsTotal += results.count

                    // Print first detection every 30 frames
                    if frameCount % 30 == 0 {
                        print("Frame \(frameCount): \(results.count) rectangle(s) detected")
                        if let first = results.first {
                            let box = first.boundingBox
                            print("  First: x=\(String(format: "%.2f", box.origin.x)), " +
                                  "y=\(String(format: "%.2f", box.origin.y)), " +
                                  "w=\(String(format: "%.2f", box.size.width)), " +
                                  "h=\(String(format: "%.2f", box.size.height)), " +
                                  "conf=\(String(format: "%.2f", first.confidence))")
                        }
                    }
                }
            } catch {
                print("Vision error: \(error)")
            }
        }

        print("\n" + String(repeating: "=", count: 50))
        print("Processing complete!")
        print("Total frames: \(frameCount)")
        print("Total detections: \(detectionsTotal)")
        print("Average detections per frame: \(String(format: "%.2f", Double(detectionsTotal) / Double(frameCount)))")

        pipeline.stop()
    }
}

#else

// Stub for non-Apple platforms
@main
struct GstVisionExample {
    static func main() {
        print("Vision framework is only available on macOS/iOS")
        print("This example demonstrates CVPixelBuffer + Vision integration")
    }
}

#endif
