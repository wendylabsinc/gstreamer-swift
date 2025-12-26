#if canImport(Vision)
import GStreamer
import AppKit
import Synchronization
@preconcurrency import Vision
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

        // Create rectangle detection request
        let rectangleRequest = VNDetectFaceRectanglesRequest()

        let frameCount = Mutex(0)
        let detectionsTotal = Mutex(0)

        try await withPipeline {
            URIDecodeSource(uri: "rtsp://joannis:wendylabs@192.168.0.112:554/stream1")
            RawVideoFormat(
                layout: BGRA<640, 480>.self
            )
        } withEachFrame: { frame in
            let frameCountValue = frameCount.withLock { value in
                value += 1
                return value
            }

            // Convert to CVPixelBuffer for Vision
            guard let pixelBuffer = try frame.rawFrame.toCVPixelBuffer() else {
                print("Frame \(frameCountValue): Failed to create CVPixelBuffer")
                return
            }

            // Run Vision detection
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

            try handler.perform([rectangleRequest])

            if let results = rectangleRequest.results, !results.isEmpty {
                detectionsTotal.withLock { $0 += results.count }

                // Print first detection every 30 frames
                if frameCountValue % 30 == 0 {
                    print("Frame \(frameCountValue): \(results.count) rectangle(s) detected")
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
        }

        print("\n" + String(repeating: "=", count: 50))
        print("Processing complete!")
        print("Total frames: \(frameCount.withLock { $0 })")
        print("Total detections: \(detectionsTotal.withLock { $0 })")
        print("Average detections per frame: \(String(format: "%.2f", Double(detectionsTotal.withLock { $0 }) / Double(frameCount.withLock { $0 })))")
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
