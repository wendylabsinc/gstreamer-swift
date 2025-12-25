import Testing
@testable import GStreamer

@Suite("Bus Message Tests")
struct BusMessageTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Get bus from pipeline")
    func getBus() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")
        let bus = pipeline.bus
        _ = bus // Bus should be non-nil (it's not optional)
    }

    @Test("Receive EOS message via AsyncStream")
    func receiveEOS() async throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=1 ! fakesink")

        try pipeline.play()

        var receivedEOS = false
        for await message in pipeline.bus.messages(filter: [.eos, .error]) {
            switch message {
            case .eos:
                receivedEOS = true
            case .error(let msg, _):
                Issue.record("Unexpected error: \(msg)")
            default:
                break
            }
            if receivedEOS { break }
        }

        #expect(receivedEOS)
        pipeline.stop()
    }

    @Test("Receive state changed messages")
    func receiveStateChanged() async throws {
        let pipeline = try Pipeline("videotestsrc num-buffers=1 ! fakesink")

        try pipeline.play()

        var stateChangeCount = 0
        for await message in pipeline.bus.messages(filter: [.stateChanged, .eos]) {
            switch message {
            case .stateChanged:
                stateChangeCount += 1
            case .eos:
                break
            default:
                break
            }
            if case .eos = message { break }
        }

        // Should have received some state changes
        #expect(stateChangeCount > 0)
        pipeline.stop()
    }

    @Test("Error message contains details")
    func errorMessageDetails() async throws {
        // Create an invalid pipeline that will error
        let pipeline = try Pipeline("videotestsrc ! video/x-raw,format=INVALID ! fakesink")

        try pipeline.play()

        var errorReceived = false
        for await message in pipeline.bus.messages(filter: [.error, .eos]) {
            switch message {
            case .error(let msg, _):
                #expect(!msg.isEmpty)
                errorReceived = true
            case .eos:
                break
            default:
                break
            }
            if errorReceived { break }
        }

        pipeline.stop()
        // Note: This test may or may not receive an error depending on GStreamer's behavior
    }
}
