import Testing
@testable import GStreamer

// MARK: - Test Tags

extension Tag {
    /// Tests related to element factories.
    @Tag static var factory: Self
    /// Tests related to element properties.
    @Tag static var properties: Self
    /// Tests related to pads and linking.
    @Tag static var pads: Self
}

@Suite("Element Tests")
struct ElementTests {

    init() throws {
        try GStreamer.initialize()
    }

    // MARK: - Factory Tests

    @Test("Create element from various factories", .tags(.factory), arguments: [
        ("queue", "myqueue"),
        ("fakesink", "testsink"),
        ("fakesrc", "testsrc"),
        ("identity", "passthrough"),
        ("tee", "splitter"),
    ])
    func createFromFactory(factory: String, name: String) throws {
        let element = try Element.make(factory: factory, name: name)
        #expect(element.name == name)
    }

    @Test("Create element with auto-generated name", .tags(.factory), arguments: [
        "queue",
        "fakesink",
        "identity",
    ])
    func createWithAutoName(factory: String) throws {
        let element = try Element.make(factory: factory)
        #expect(!element.name.isEmpty)
    }

    @Test("Invalid factory throws error", .tags(.factory), arguments: [
        "nonexistent_element_xyz",
        "not_a_real_plugin",
        "",
    ])
    func invalidFactory(factory: String) throws {
        #expect(throws: GStreamerError.self) {
            _ = try Element.make(factory: factory)
        }
    }

    // MARK: - Pad Tests

    @Test("Get static pad", .tags(.pads))
    func getStaticPad() throws {
        let queue = try Element.make(factory: "queue")

        let sinkPad = queue.staticPad("sink")
        #expect(sinkPad != nil)

        let srcPad = queue.staticPad("src")
        #expect(srcPad != nil)

        let invalidPad = queue.staticPad("nonexistent")
        #expect(invalidPad == nil)
    }

    @Test("Link elements", .tags(.pads))
    func linkElements() throws {
        let src = try Element.make(factory: "videotestsrc")
        let sink = try Element.make(factory: "fakesink")

        let success = src.link(to: sink)
        #expect(success)
    }

    @Test("Add element to pipeline and sync state", .tags(.pads))
    func addToPipeline() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")

        let queue = try Element.make(factory: "queue", name: "testqueue")
        let added = pipeline.add(queue)
        #expect(added)

        // Find it by name
        let found = pipeline.element(named: "testqueue")
        #expect(found != nil)
    }

    @Test("Request pad from tee", .tags(.pads))
    func requestPadFromTee() throws {
        let tee = try Element.make(factory: "tee")

        let pad1 = tee.requestPad("src_%u")
        #expect(pad1 != nil)

        let pad2 = tee.requestPad("src_%u")
        #expect(pad2 != nil)

        // Pads should be different
        #expect(pad1!.pad != pad2!.pad)

        // Release pads
        if let p1 = pad1 { tee.releasePad(p1) }
        if let p2 = pad2 { tee.releasePad(p2) }
    }

    // MARK: - Property Tests

    @Test("Boolean property round-trip", .tags(.properties), arguments: [true, false])
    func boolProperty(value: Bool) throws {
        let src = try Element.make(factory: "videotestsrc")
        src.set("is-live", value)
        #expect(src.getBool("is-live") == value)
    }

    @Test("Integer property round-trip", .tags(.properties), arguments: [0, 1, 2, 5, 10])
    func intProperty(pattern: Int) throws {
        let src = try Element.make(factory: "videotestsrc")
        src.set("pattern", pattern)
        #expect(src.getInt("pattern") == pattern)
    }

    @Test("String property round-trip", .tags(.properties), arguments: [
        "/tmp/test.mp4",
        "/var/log/output.mkv",
        "/home/user/video.avi",
    ])
    func stringProperty(location: String) throws {
        let sink = try Element.make(factory: "filesink")
        sink.set("location", location)
        #expect(sink.getString("location") == location)
    }

    @Test("Double property round-trip", .tags(.properties), arguments: [0.0, 0.5, 1.0, 1.5, 2.0])
    func doubleProperty(value: Double) throws {
        let volume = try Element.make(factory: "volume")
        volume.set("volume", value)
        let result = volume.getDouble("volume")
        #expect(abs(result - value) < 0.001)
    }
}
