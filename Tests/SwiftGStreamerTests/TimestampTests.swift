import Testing
@testable import GStreamer

@Suite("Timestamp Tests")
struct TimestampTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("VideoFrame has PTS")
    func videoFrameHasPTS() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=3 ! \
            video/x-raw,format=BGRA,width=4,height=4,framerate=30/1 ! \
            appsink name=sink
            """
        )

        let sink = try AppSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        var frameCount = 0
        var lastPts: UInt64 = 0

        for try await frame in sink.frames() {
            frameCount += 1

            // PTS should be set for test source
            if let pts = frame.pts {
                // PTS should increase monotonically
                if frameCount > 1 {
                    #expect(pts >= lastPts)
                }
                lastPts = pts
            }

            if frameCount >= 3 { break }
        }

        #expect(frameCount == 3)
        pipeline.stop()
    }

    @Test("VideoFrame has duration")
    func videoFrameHasDuration() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=2 ! \
            video/x-raw,format=BGRA,width=4,height=4,framerate=30/1 ! \
            appsink name=sink
            """
        )

        let sink = try AppSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        for try await frame in sink.frames() {
            // Duration should be set for fixed framerate
            if let duration = frame.duration {
                // At 30fps, duration should be ~33.33ms = 33,333,333 ns
                #expect(duration > 30_000_000)
                #expect(duration < 40_000_000)
            }
            break
        }

        pipeline.stop()
    }

    @Test("AppSource PTS is preserved")
    func appSourcePTSPreserved() async throws {
        let pipeline = try Pipeline(
            """
            appsrc name=src ! \
            video/x-raw,format=BGRA,width=2,height=2,framerate=30/1 ! \
            appsink name=sink
            """
        )

        let src = try AppSource(pipeline: pipeline, name: "src")
        let sink = try AppSink(pipeline: pipeline, name: "sink")

        src.setCaps("video/x-raw,format=BGRA,width=2,height=2,framerate=30/1")
        try pipeline.play()

        // Push frames with specific timestamps
        let pixels = [UInt8](repeating: 128, count: 2 * 2 * 4)
        let testPts: UInt64 = 500_000_000  // 500ms
        let testDuration: UInt64 = 33_333_333

        try src.push(data: pixels, pts: testPts, duration: testDuration)
        src.endOfStream()

        // Verify the timestamp is preserved
        for try await frame in sink.frames() {
            if let pts = frame.pts {
                #expect(pts == testPts)
            }
            if let duration = frame.duration {
                #expect(duration == testDuration)
            }
            break
        }

        pipeline.stop()
    }

    @Test("Calculate FPS from duration")
    func calculateFPS() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=1 ! \
            video/x-raw,format=BGRA,width=4,height=4,framerate=60/1 ! \
            appsink name=sink
            """
        )

        let sink = try AppSink(pipeline: pipeline, name: "sink")
        try pipeline.play()

        for try await frame in sink.frames() {
            if let duration = frame.duration {
                let fps = 1_000_000_000.0 / Double(duration)
                // Should be approximately 60fps
                #expect(fps > 55 && fps < 65)
            }
            break
        }

        pipeline.stop()
    }
}
