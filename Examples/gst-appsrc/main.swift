import GStreamer
import Foundation

/// Example showing how to push data into a pipeline with AppSource.
///
/// Demonstrates:
/// - Generating video frames programmatically
/// - Pushing frames with proper timestamps
/// - Playing generated content to screen
@main
struct GstAppSrcExample {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")

        let width = 320
        let height = 240
        let fps = 30
        let numFrames = 90 // 3 seconds

        // Create pipeline: appsrc -> videoconvert -> autovideosink
        let pipeline = try Pipeline("""
            appsrc name=src ! \
            video/x-raw,format=BGRA,width=\(width),height=\(height),framerate=\(fps)/1 ! \
            videoconvert ! \
            autovideosink
            """)

        let source = try pipeline.appSource(named: "src")

        // Set caps for BGRA video
        source.setCaps("video/x-raw,format=BGRA,width=\(width),height=\(height),framerate=\(fps)/1")

        // Start the pipeline
        try pipeline.play()
        print("Playing generated video (\(width)x\(height) @ \(fps)fps)...")
        print("Generating \(numFrames) frames (3 seconds)\n")

        let bytesPerPixel = 4 // BGRA
        let frameSize = width * height * bytesPerPixel
        let frameDuration: UInt64 = 1_000_000_000 / UInt64(fps) // nanoseconds

        // Generate and push frames
        for frameNum in 0..<numFrames {
            // Create frame data with animated pattern
            var frameData = [UInt8](repeating: 0, count: frameSize)

            let t = Double(frameNum) / Double(numFrames)

            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * bytesPerPixel

                    // Animated gradient with moving circle
                    let centerX = Double(width) / 2 + cos(t * .pi * 4) * Double(width) / 4
                    let centerY = Double(height) / 2 + sin(t * .pi * 4) * Double(height) / 4
                    let dx = Double(x) - centerX
                    let dy = Double(y) - centerY
                    let dist = sqrt(dx * dx + dy * dy)
                    let radius = 50.0

                    if dist < radius {
                        // Circle color (animated hue)
                        let hue = t * 360
                        let (r, g, b) = hsvToRgb(h: hue, s: 1.0, v: 1.0)
                        frameData[offset + 0] = UInt8(b * 255) // B
                        frameData[offset + 1] = UInt8(g * 255) // G
                        frameData[offset + 2] = UInt8(r * 255) // R
                        frameData[offset + 3] = 255            // A
                    } else {
                        // Background gradient
                        frameData[offset + 0] = UInt8((Double(x) / Double(width)) * 128)  // B
                        frameData[offset + 1] = UInt8((Double(y) / Double(height)) * 128) // G
                        frameData[offset + 2] = UInt8(t * 64)                              // R
                        frameData[offset + 3] = 255                                        // A
                    }
                }
            }

            // Calculate timestamps
            let pts = UInt64(frameNum) * frameDuration

            // Push frame to pipeline
            try source.push(data: frameData, pts: pts, duration: frameDuration)

            // Progress indicator
            if frameNum % fps == 0 {
                print("Frame \(frameNum)/\(numFrames) (\(frameNum / fps)s)")
            }

            // Small delay to match real-time playback
            try await Task.sleep(for: .milliseconds(1000 / fps))
        }

        // Signal end of stream
        source.endOfStream()
        print("\nSent EOS, waiting for playback to complete...")

        // Wait for EOS
        for await message in pipeline.bus.messages(filter: [.eos, .error]) {
            switch message {
            case .eos:
                print("Playback complete!")
            case .error(let msg, _):
                print("Error: \(msg)")
            default:
                break
            }
            break
        }

        pipeline.stop()
    }

    /// Convert HSV to RGB (all values 0-1)
    static func hsvToRgb(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c

        let (r1, g1, b1): (Double, Double, Double)
        switch h {
        case 0..<60: (r1, g1, b1) = (c, x, 0)
        case 60..<120: (r1, g1, b1) = (x, c, 0)
        case 120..<180: (r1, g1, b1) = (0, c, x)
        case 180..<240: (r1, g1, b1) = (0, x, c)
        case 240..<300: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }

        return (r1 + m, g1 + m, b1 + m)
    }
}
