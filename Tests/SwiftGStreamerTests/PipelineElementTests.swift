import Testing
@testable import GStreamer

@Suite("Pipeline Element Tests")
struct PipelineElementTests {

    init() throws {
        try GStreamer.initialize()
    }

    // MARK: - VideoRate Tests

    @Test("VideoRate default pipeline")
    func videoRateDefault() {
        let rate = VideoRate()
        #expect(rate.pipeline == "videorate")
    }

    @Test("VideoRate with dropOnly")
    func videoRateDropOnly() {
        let rate = VideoRate(dropOnly: true)
        #expect(rate.pipeline.contains("drop-only=true"))
    }

    @Test("VideoRate with skipToFirst")
    func videoRateSkipToFirst() {
        let rate = VideoRate(skipToFirst: true)
        #expect(rate.pipeline.contains("skip-to-first=true"))
    }

    // MARK: - VideoFlip Tests

    @Test("VideoFlip rotation methods")
    func videoFlipRotation() {
        #expect(VideoFlip.rotate90.pipeline == "videoflip method=1")
        #expect(VideoFlip.rotate180.pipeline == "videoflip method=2")
        #expect(VideoFlip.rotate270.pipeline == "videoflip method=3")
    }

    @Test("VideoFlip mirror methods")
    func videoFlipMirror() {
        #expect(VideoFlip.horizontalFlip.pipeline == "videoflip method=4")
        #expect(VideoFlip.verticalFlip.pipeline == "videoflip method=5")
    }

    @Test("VideoFlip automatic")
    func videoFlipAutomatic() {
        #expect(VideoFlip.automatic.pipeline == "videoflip method=8")
    }

    @Test("VideoMirror preserves type")
    func videoMirrorPreservesType() {
        let mirror = VideoMirror<BGRA<1920, 1080>>()
        #expect(mirror.pipeline == "videoflip method=4")
    }

    @Test("VideoVerticalFlip preserves type")
    func videoVerticalFlipPreservesType() {
        let flip = VideoVerticalFlip<BGRA<1920, 1080>>()
        #expect(flip.pipeline == "videoflip method=5")
    }

    @Test("VideoRotate180 preserves type")
    func videoRotate180PreservesType() {
        let rotate = VideoRotate180<BGRA<1920, 1080>>()
        #expect(rotate.pipeline == "videoflip method=2")
    }

    @Test("VideoRotate90 swaps dimensions in type")
    func videoRotate90SwapsDimensions() {
        let rotate = VideoRotate90<BGRA<1920, 1080>>()
        #expect(rotate.pipeline == "videoflip method=1")
        // Type check: Input is BGRA<1920, 1080>, Output is BGRA<1080, 1920>
        // This is verified at compile time by the associated types
    }

    @Test("VideoRotate270 swaps dimensions in type")
    func videoRotate270SwapsDimensions() {
        let rotate = VideoRotate270<BGRA<1920, 1080>>()
        #expect(rotate.pipeline == "videoflip method=3")
    }


    // MARK: - VideoCrop Tests

    @Test("VideoCrop with individual edges")
    func videoCropEdges() {
        let crop = VideoCrop(top: 10, bottom: 20, left: 30, right: 40)
        #expect(crop.pipeline.contains("top=10"))
        #expect(crop.pipeline.contains("bottom=20"))
        #expect(crop.pipeline.contains("left=30"))
        #expect(crop.pipeline.contains("right=40"))
    }

    @Test("VideoCrop symmetric")
    func videoCropSymmetric() {
        let crop = VideoCrop(horizontal: 50, vertical: 25)
        #expect(crop.pipeline.contains("top=25"))
        #expect(crop.pipeline.contains("bottom=25"))
        #expect(crop.pipeline.contains("left=50"))
        #expect(crop.pipeline.contains("right=50"))
    }

    @Test("VideoCrop uniform")
    func videoCropUniform() {
        let crop = VideoCrop(all: 100)
        #expect(crop.pipeline.contains("top=100"))
        #expect(crop.pipeline.contains("bottom=100"))
        #expect(crop.pipeline.contains("left=100"))
        #expect(crop.pipeline.contains("right=100"))
    }

    // MARK: - Queue Tests

    @Test("Queue default pipeline")
    func queueDefault() {
        let queue = Queue()
        #expect(queue.pipeline == "queue")
    }

    @Test("Queue with maxBuffers")
    func queueMaxBuffers() {
        let queue = Queue(maxBuffers: 10)
        #expect(queue.pipeline.contains("max-size-buffers=10"))
    }

    @Test("Queue leaky")
    func queueLeaky() {
        let queue = Queue.leaky(maxBuffers: 1)
        #expect(queue.pipeline.contains("max-size-buffers=1"))
        #expect(queue.pipeline.contains("leaky=1"))
    }

    // MARK: - Deinterlace Tests

    @Test("Deinterlace default pipeline")
    func deinterlaceDefault() {
        let deinterlace = Deinterlace()
        #expect(deinterlace.pipeline.contains("deinterlace"))
        #expect(deinterlace.pipeline.contains("mode=0"))
        #expect(deinterlace.pipeline.contains("method=0"))
    }

    @Test("Deinterlace linearBlend")
    func deinterlaceLinearBlend() {
        let deinterlace = Deinterlace.linearBlend
        #expect(deinterlace.pipeline.contains("mode=1"))
        #expect(deinterlace.pipeline.contains("method=3"))
    }

    // MARK: - AutoVideoSink Tests

    @Test("AutoVideoSink default pipeline")
    func autoVideoSinkDefault() {
        let sink = AutoVideoSink()
        #expect(sink.pipeline == "autovideosink")
    }

    @Test("AutoVideoSink live (no sync)")
    func autoVideoSinkLive() {
        let sink = AutoVideoSink.live
        #expect(sink.pipeline.contains("autovideosink"))
        #expect(sink.pipeline.contains("sync=false"))
    }

    @Test("FakeVideoSink pipeline")
    func fakeVideoSink() {
        let sink = FakeVideoSink()
        #expect(sink.pipeline.contains("fakesink"))
        #expect(sink.pipeline.contains("sync=false"))
    }

    // MARK: - CameraSource Tests

    @Test("CameraSource default")
    func cameraSourceDefault() {
        let source = CameraSource()
        #if os(macOS) || os(iOS)
        #expect(source.pipeline.contains("avfvideosrc"))
        #elseif os(Linux)
        #expect(source.pipeline.contains("v4l2src"))
        #endif
    }

    @Test("CameraSource with device index")
    func cameraSourceDeviceIndex() {
        let source = CameraSource(deviceIndex: 1)
        #if os(macOS) || os(iOS)
        #expect(source.pipeline.contains("device-index=1"))
        #elseif os(Linux)
        #expect(source.pipeline.contains("/dev/video1"))
        #endif
    }

    // MARK: - Pipeline Integration Tests

    @Test("Build pipeline with VideoRate")
    func buildPipelineWithVideoRate() throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=1 ! videorate ! fakesink")
        try pipeline.play()
        pipeline.stop()
    }

    @Test("Build pipeline with VideoFlip")
    func buildPipelineWithVideoFlip() throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=1 ! videoflip method=1 ! fakesink")
        try pipeline.play()
        pipeline.stop()
    }

    @Test("Build pipeline with VideoCrop")
    func buildPipelineWithVideoCrop() throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=1 ! video/x-raw,width=320,height=240 ! videocrop top=10 bottom=10 left=10 right=10 ! fakesink")
        try pipeline.play()
        pipeline.stop()
    }

    @Test("Build pipeline with Queue")
    func buildPipelineWithQueue() throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=1 ! queue max-size-buffers=5 ! fakesink")
        try pipeline.play()
        pipeline.stop()
    }
}
