import Testing
@testable import GStreamer

@Suite("Seek and Position Tests")
struct SeekTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Query position from playing pipeline")
    func queryPosition() async throws {
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=100 ! \
            video/x-raw,framerate=30/1 ! \
            fakesink
            """
        )

        try pipeline.play()

        // Wait a bit for pipeline to start
        try await Task.sleep(for: .milliseconds(100))

        // Position should be queryable
        let position = pipeline.position
        // Position may or may not be available depending on timing
        if let pos = position {
            #expect(pos >= 0)
        }

        pipeline.stop()
    }

    @Test("Duration returns nil for live source")
    func durationNilForLive() async throws {
        let pipeline = try Pipeline("videotestsrc is-live=true ! fakesink")

        try pipeline.play()
        try await Task.sleep(for: .milliseconds(100))

        // Duration should be nil for live sources
        let duration = pipeline.duration
        #expect(duration == nil)

        pipeline.stop()
    }

    @Test("SeekFlags construction")
    func seekFlagsConstruction() {
        let flush = Pipeline.SeekFlags.flush
        let keyUnit = Pipeline.SeekFlags.keyUnit
        let accurate = Pipeline.SeekFlags.accurate

        // Flags should be combinable
        let combined: Pipeline.SeekFlags = [.flush, .keyUnit]
        #expect(combined.contains(.flush))
        #expect(combined.contains(.keyUnit))
        #expect(!combined.contains(.accurate))

        // Each flag should have a non-zero value
        #expect(flush.rawValue != 0)
        #expect(keyUnit.rawValue != 0)
        #expect(accurate.rawValue != 0)
    }

    @Test("Seek on non-seekable source doesn't crash")
    func seekNonSeekable() async throws {
        // Test patterns aren't seekable but the API should handle it gracefully
        let pipeline = try Pipeline("videotestsrc num-buffers=10 ! fakesink")

        try pipeline.play()
        try await Task.sleep(for: .milliseconds(50))

        // This may throw, but shouldn't crash
        do {
            try pipeline.seek(to: 0)
        } catch {
            // Expected for non-seekable sources
        }

        pipeline.stop()
    }
}
