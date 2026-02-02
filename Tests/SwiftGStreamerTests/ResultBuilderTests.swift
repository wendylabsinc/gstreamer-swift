import Testing
@testable import GStreamer

@Suite("Result Builder Tests")
struct ResultBuilderTests {

    init() throws {
        try GStreamer.initialize()
    }

    // MARK: - Untyped Pipeline Tests

    @Test("Untyped pipeline with VideoTestSource")
    func untypedSourceOnly() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videotestsrc"))
    }

    @Test("Untyped pipeline with TextOverlay")
    func untypedTextOverlay() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            TextOverlay("Hello", position: .topLeft)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videotestsrc"))
        #expect(pipeline.pipeline.contains("textoverlay"))
        #expect(pipeline.pipeline.contains("text=\"Hello\""))
        #expect(pipeline.pipeline.contains("valignment=6"))
    }

    @Test("Untyped pipeline with ClockOverlay")
    func untypedClockOverlay() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            ClockOverlay(position: .topRight, shaded: true)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("clockoverlay"))
        #expect(pipeline.pipeline.contains("shaded-background=true"))
    }

    @Test("Untyped pipeline with TimeOverlay")
    func untypedTimeOverlay() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            TimeOverlay(timeMode: .runningTime)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("timeoverlay"))
        #expect(pipeline.pipeline.contains("time-mode=2"))
    }

    @Test("Untyped pipeline with Queue")
    func untypedQueue() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Queue(maxBuffers: 5, leaky: .upstream)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("queue"))
        #expect(pipeline.pipeline.contains("max-size-buffers=5"))
        #expect(pipeline.pipeline.contains("leaky=1"))
    }

    @Test("Untyped pipeline with Identity")
    func untypedIdentity() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Identity(silent: false)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("identity"))
        #expect(pipeline.pipeline.contains("silent=false"))
    }

    @Test("Untyped pipeline with Valve")
    func untypedValve() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Valve(drop: true)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("valve"))
        #expect(pipeline.pipeline.contains("drop=true"))
    }

    @Test("Untyped pipeline with VideoBalance")
    func untypedVideoBalance() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            VideoBalance(brightness: 0.5, contrast: 1.2)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videobalance"))
        #expect(pipeline.pipeline.contains("brightness=0.5"))
        #expect(pipeline.pipeline.contains("contrast=1.2"))
    }

    @Test("Untyped pipeline with FakeSink")
    func untypedFakeSink() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<Never> {
            VideoTestSource()
            FakeSink(sync: true)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("fakesink"))
        #expect(!pipeline.pipeline.contains("sync=false"))
    }

    @Test("Untyped pipeline with multiple elements")
    func untypedMultipleElements() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Queue(maxBuffers: 2)
            VideoBalance(saturation: 0.0)
            TextOverlay("Test")
            Identity()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videotestsrc"))
        #expect(pipeline.pipeline.contains("queue"))
        #expect(pipeline.pipeline.contains("videobalance"))
        #expect(pipeline.pipeline.contains("textoverlay"))
        #expect(pipeline.pipeline.contains("identity"))

        // Verify order with ! separators
        let components = pipeline.pipeline.split(separator: "!")
        #expect(components.count == 5)
    }

    // MARK: - Typed Pipeline Tests (Layout Inferred)

    @Test("Typed pipeline with TextOverlay - layout inferred")
    func typedTextOverlay() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            TextOverlay("Recording", position: .bottomRight)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videotestsrc"))
        #expect(pipeline.pipeline.contains("textoverlay"))
        #expect(pipeline.pipeline.contains("text=\"Recording\""))
    }

    @Test("Typed pipeline with ClockOverlay - layout inferred")
    func typedClockOverlay() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1280, 720>>> {
            TypedVideoTestSource<BGRA<1280, 720>>()
            ClockOverlay(position: .top, timeFormat: "%H:%M")  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("clockoverlay"))
        #expect(pipeline.pipeline.contains("time-format=\"%H:%M\""))
    }

    @Test("Typed pipeline with TimeOverlay - layout inferred")
    func typedTimeOverlay() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<NV12<640, 480>>> {
            TypedVideoTestSource<NV12<640, 480>>()
            TimeOverlay(timeMode: .bufferCount)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("timeoverlay"))
        #expect(pipeline.pipeline.contains("time-mode=3"))
    }

    @Test("Typed pipeline with Queue - layout inferred")
    func typedQueue() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            Queue(maxBuffers: 10, maxBytes: 1024)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("queue"))
        #expect(pipeline.pipeline.contains("max-size-buffers=10"))
        #expect(pipeline.pipeline.contains("max-size-bytes=1024"))
    }

    @Test("Typed pipeline with Identity - layout inferred")
    func typedIdentity() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<I420<800, 600>>> {
            TypedVideoTestSource<I420<800, 600>>()
            Identity(singleSegment: true)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("identity"))
        #expect(pipeline.pipeline.contains("single-segment=true"))
    }

    @Test("Typed pipeline with Valve - layout inferred")
    func typedValve() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<320, 240>>> {
            TypedVideoTestSource<BGRA<320, 240>>()
            Valve(drop: false)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("valve"))
        #expect(pipeline.pipeline.contains("drop=false"))
    }

    @Test("Typed pipeline with VideoBalance - layout inferred")
    func typedVideoBalance() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoBalance(hue: 0.5, saturation: 1.5)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videobalance"))
        #expect(pipeline.pipeline.contains("hue=0.5"))
        #expect(pipeline.pipeline.contains("saturation=1.5"))
    }

    @Test("Typed pipeline with FakeSink - layout inferred")
    func typedFakeSink() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<Never> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            FakeSink(silent: false)  // No type parameter needed!
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("fakesink"))
        #expect(pipeline.pipeline.contains("silent=false"))
    }

    @Test("Typed pipeline with multiple elements - all layouts inferred")
    func typedMultipleElements() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            Queue(maxBuffers: 3)           // Layout inferred
            VideoBalance(brightness: 0.1)  // Layout inferred
            TextOverlay("Overlay")         // Layout inferred
            Identity()                     // Layout inferred
        }

        let pipeline = build()
        let components = pipeline.pipeline.split(separator: "!")
        #expect(components.count == 5)
    }

    // MARK: - Typed Pipeline with Rotation Tests

    @Test("Typed pipeline with VideoMirror preserves dimensions")
    func typedVideoMirror() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoMirror<BGRA<1920, 1080>>()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videoflip method=4"))
    }

    @Test("Typed pipeline with VideoVerticalFlip preserves dimensions")
    func typedVideoVerticalFlip() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoVerticalFlip<BGRA<1920, 1080>>()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videoflip method=5"))
    }

    @Test("Typed pipeline with VideoRotate180 preserves dimensions")
    func typedVideoRotate180() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoRotate180<BGRA<1920, 1080>>()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videoflip method=2"))
    }

    @Test("Typed pipeline with VideoRotate90 swaps dimensions")
    func typedVideoRotate90() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1080, 1920>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoRotate90<BGRA<1920, 1080>>()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videoflip method=1"))
    }

    @Test("Typed pipeline with VideoRotate270 swaps dimensions")
    func typedVideoRotate270() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1080, 1920>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoRotate270<BGRA<1920, 1080>>()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videoflip method=3"))
    }

    @Test("Typed pipeline with chained rotations")
    func typedChainedRotations() {
        // Rotate 90 twice = rotate 180, dimensions should be back to original
        @VideoPipelineBuilder
        func build() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            VideoRotate90<BGRA<1920, 1080>>()  // 1920x1080 -> 1080x1920
            VideoRotate90<BGRA<1080, 1920>>()  // 1080x1920 -> 1920x1080
        }

        let pipeline = build()
        let components = pipeline.pipeline.split(separator: "!")
        #expect(components.count == 3)
    }

    // MARK: - Complex Pipeline Tests

    @Test("Complex untyped pipeline")
    func complexUntypedPipeline() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<Never> {
            VideoTestSource(pattern: .smpte)
            VideoConvert()
            Queue(maxBuffers: 5, leaky: .downstream)
            VideoBalance(brightness: 0.2, saturation: 1.3)
            TextOverlay("Recording", position: .topLeft, shaded: true)
            ClockOverlay(position: .bottomRight)
            Identity()
            FakeSink()
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videotestsrc pattern=smpte"))
        #expect(pipeline.pipeline.contains("videoconvert"))
        #expect(pipeline.pipeline.contains("queue"))
        #expect(pipeline.pipeline.contains("leaky=2"))
        #expect(pipeline.pipeline.contains("videobalance"))
        #expect(pipeline.pipeline.contains("textoverlay"))
        #expect(pipeline.pipeline.contains("shaded-background=true"))
        #expect(pipeline.pipeline.contains("clockoverlay"))
        #expect(pipeline.pipeline.contains("identity"))
        #expect(pipeline.pipeline.contains("fakesink"))
    }

    @Test("Complex typed pipeline with format and overlays - all layouts inferred")
    func complexTypedPipeline() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<Never> {
            TypedVideoTestSource<BGRA<1920, 1080>>()
            Queue(maxBuffers: 2)
            VideoBalance(contrast: 1.1)
            TextOverlay("Live", position: .topLeft, color: 0xFFFF0000)
            ClockOverlay(position: .bottomRight, shaded: true)
            TimeOverlay(position: .bottom, timeMode: .runningTime)
            Identity()
            FakeSink()
        }

        let pipeline = build()
        let components = pipeline.pipeline.split(separator: "!")
        #expect(components.count == 8)
    }

    // MARK: - Static Helpers Tests

    @Test("Queue.leaky static method")
    func queueLeakyStatic() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Queue.leaky(maxBuffers: 1)
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("max-size-buffers=1"))
        #expect(pipeline.pipeline.contains("leaky=1"))
    }

    @Test("Identity.debug static property")
    func identityDebugStatic() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Identity.debug
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("identity"))
        #expect(pipeline.pipeline.contains("silent=false"))
    }

    @Test("Valve.closed static property")
    func valveClosedStatic() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Valve.closed
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("valve"))
        #expect(pipeline.pipeline.contains("drop=true"))
    }

    @Test("Valve.open static property")
    func valveOpenStatic() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            Valve.open
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("valve"))
        #expect(pipeline.pipeline.contains("drop=false"))
    }

    @Test("VideoBalance.grayscale static property")
    func videoBalanceGrayscaleStatic() {
        @VideoPipelineBuilder
        func build() -> PartialPipeline<VideoFrame> {
            VideoTestSource()
            VideoBalance.grayscale
        }

        let pipeline = build()
        #expect(pipeline.pipeline.contains("videobalance"))
        #expect(pipeline.pipeline.contains("saturation=0.0"))
    }
}

// MARK: - Test Helpers

/// Typed video test source for use in typed pipeline tests.
struct TypedVideoTestSource<Layout: PixelLayoutProtocol>: VideoPipelineSource {
    typealias VideoFrameOutput = _VideoFrame<Layout>

    var pipeline: String { "videotestsrc" }

    init() {}
}
