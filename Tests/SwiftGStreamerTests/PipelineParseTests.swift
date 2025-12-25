import Testing
@testable import GStreamer

@Suite("Pipeline Parse Tests")
struct PipelineParseTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Parse simple pipeline")
    func parseSimplePipeline() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")
        #expect(pipeline.currentState() == .null)
    }

    @Test("Parse pipeline with named elements")
    func parseNamedElements() throws {
        let pipeline = try Pipeline("videotestsrc name=src ! fakesink name=sink")

        let src = pipeline.element(named: "src")
        #expect(src != nil)
        #expect(src?.name == "src")

        let sink = pipeline.element(named: "sink")
        #expect(sink != nil)
        #expect(sink?.name == "sink")
    }

    @Test("Parse invalid pipeline fails")
    func parseInvalidPipeline() throws {
        #expect(throws: GStreamerError.self) {
            _ = try Pipeline("this-is-not-a-valid-element !!!")
        }
    }

    @Test("Set pipeline state")
    func setPipelineState() async throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")

        try pipeline.setState(.ready)

        // Give it time to transition
        try? await Task.sleep(for: .milliseconds(100))
        let state = pipeline.currentState()
        #expect(state == .ready || state == .paused || state == .playing)

        pipeline.stop()
    }

    @Test("Element not found returns nil")
    func elementNotFound() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")
        let element = pipeline.element(named: "nonexistent")
        #expect(element == nil)
    }

    @Test("Play and stop pipeline")
    func playAndStop() async throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=5 ! fakesink")

        try pipeline.play()

        // State changes are async, wait for pipeline to start
        try? await Task.sleep(for: .milliseconds(50))
        let playingState = pipeline.currentState()
        #expect(playingState == .playing || playingState == .paused || playingState == .ready)

        pipeline.stop()

        // Wait for stop to complete
        try? await Task.sleep(for: .milliseconds(50))
        #expect(pipeline.currentState() == .null)
    }
}
