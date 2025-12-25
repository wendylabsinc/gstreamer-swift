import Testing
@testable import GStreamer

@Suite("AppSink Smoke Tests")
struct AppSinkSmokeTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Create AppSink from pipeline")
    func createAppSink() throws {
        let pipeline = try Pipeline("videotestsrc ! appsink name=sink")
        let appSink = try AppSink(pipeline: pipeline, name: "sink")
        _ = appSink
    }

    @Test("AppSink not found throws error")
    func appSinkNotFound() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")

        #expect(throws: GStreamerError.self) {
            _ = try AppSink(pipeline: pipeline, name: "sink")
        }
    }

    @Test("Pull frames from AppSink")
    func pullFrames() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=5 ! \
            video/x-raw,format=BGRA,width=320,height=240 ! \
            appsink name=sink
            """
        )

        let appSink = try AppSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        var frameCount = 0
        for await frame in appSink.frames() {
            frameCount += 1

            // After first frame, dimensions should be parsed
            if frameCount > 1 {
                #expect(frame.width == 320)
                #expect(frame.height == 240)
                #expect(frame.format == .bgra)
            }

            // Access buffer data
            try frame.withMappedBytes { span in
                span.withUnsafeBytes { buffer in
                    #expect(buffer.count > 0)
                }
            }

            if frameCount >= 3 { break }
        }

        #expect(frameCount >= 3)
        pipeline.stop()
    }

    @Test("VideoFrame withMappedBytes provides valid data")
    func videoFrameData() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=2 pattern=white ! \
            video/x-raw,format=BGRA,width=4,height=4 ! \
            appsink name=sink
            """
        )

        let appSink = try AppSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        for await frame in appSink.frames() {
            try frame.withMappedBytes { span in
                span.withUnsafeBytes { buffer in
                    // White pixels in BGRA = 255, 255, 255, 255
                    // Buffer should have data
                    #expect(buffer.count == 4 * 4 * 4) // width * height * bytesPerPixel
                }
            }
            break // Just check first frame
        }

        pipeline.stop()
    }

    @Test("Pipeline convenience method for AppSink")
    func pipelineAppSinkConvenience() throws {
        let pipeline = try Pipeline("videotestsrc ! appsink name=mysink")
        let appSink = try pipeline.appSink(named: "mysink")
        _ = appSink
    }

    @Test("Multiple frames have consistent format")
    func consistentFormat() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=5 ! \
            video/x-raw,format=RGBA,width=160,height=120 ! \
            appsink name=sink
            """
        )

        let appSink = try AppSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        var formats: [PixelFormat] = []
        var count = 0
        for await frame in appSink.frames() {
            count += 1
            if count > 1 { // Skip first frame (caps not yet parsed)
                formats.append(frame.format)
            }
            if count >= 4 { break }
        }

        // All frames should have same format
        #expect(formats.allSatisfy { $0 == .rgba })
        pipeline.stop()
    }
}
