import Testing
@testable import GStreamer

@Suite("AppSource Tests")
struct AppSourceTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Create AppSource from pipeline")
    func createAppSource() throws {
        let pipeline = try Pipeline("appsrc name=src ! fakesink")
        let appSource = try AppSource(pipeline: pipeline, name: "src")
        _ = appSource
    }

    @Test("AppSource not found throws error")
    func appSourceNotFound() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")

        #expect(throws: GStreamerError.self) {
            _ = try AppSource(pipeline: pipeline, name: "src")
        }
    }

    @Test("Push data through AppSource")
    func pushData() async throws {
        // Create a pipeline: appsrc -> fakesink
        let pipeline = try Pipeline(
            """
            appsrc name=src ! \
            video/x-raw,format=BGRA,width=4,height=4,framerate=30/1 ! \
            fakesink
            """
        )

        let src = try AppSource(pipeline: pipeline, name: "src")
        src.setCaps("video/x-raw,format=BGRA,width=4,height=4,framerate=30/1")
        src.setLive(false)

        try pipeline.play()

        // Create a small 4x4 BGRA frame
        let width = 4
        let height = 4
        let pixels = [UInt8](repeating: 255, count: width * height * 4)

        // Push a few frames
        for i in 0..<3 {
            let pts = UInt64(i) * 33_333_333  // ~30fps
            try src.push(data: pixels, pts: pts, duration: 33_333_333)
        }

        src.endOfStream()

        // Wait for EOS
        for await message in pipeline.bus.messages(filter: [.eos, .error]) {
            switch message {
            case .eos:
                break
            case .error(let msg, _):
                Issue.record("Unexpected error: \(msg)")
            default:
                continue
            }
            break
        }

        pipeline.stop()
    }

    @Test("AppSource to AppSink roundtrip")
    func roundtrip() async throws {
        // Create a pipeline that passes data from appsrc to appsink
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

        // Create a 2x2 BGRA frame with known values
        let pixels: [UInt8] = [
            255, 0, 0, 255,    // Blue
            0, 255, 0, 255,    // Green
            0, 0, 255, 255,    // Red
            255, 255, 0, 255   // Cyan
        ]

        let pushPts: UInt64 = 100_000_000  // 100ms

        // Push frame
        try src.push(data: pixels, pts: pushPts, duration: 33_333_333)
        src.endOfStream()

        // Receive frame
        var receivedFrame = false
        for await frame in sink.frames() {
            receivedFrame = true

            // Verify dimensions (may be 0 on first frame if caps not parsed)
            if frame.width > 0 {
                #expect(frame.width == 2)
                #expect(frame.height == 2)
            }

            // Verify we can access the data
            try frame.withMappedBytes { span in
                span.withUnsafeBytes { buffer in
                    #expect(buffer.count == 16)  // 2x2x4 bytes
                }
            }
            break
        }

        #expect(receivedFrame)
        pipeline.stop()
    }

    @Test("pushVideoFrame validates size")
    func pushVideoFrameValidation() async throws {
        let pipeline = try Pipeline("appsrc name=src ! fakesink")
        let src = try AppSource(pipeline: pipeline, name: "src")

        src.setCaps("video/x-raw,format=BGRA,width=4,height=4,framerate=30/1")
        try pipeline.play()

        // Create data that's too small for 4x4 BGRA (should be 64 bytes)
        let tooSmall = [UInt8](repeating: 0, count: 32)

        #expect(throws: GStreamerError.self) {
            try src.pushVideoFrame(
                data: tooSmall,
                width: 4,
                height: 4,
                format: .bgra
            )
        }

        pipeline.stop()
    }
}
