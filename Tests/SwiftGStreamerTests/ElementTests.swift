import Testing
@testable import GStreamer

@Suite("Element Tests")
struct ElementTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Create element from factory")
    func createFromFactory() throws {
        let queue = try Element.make(factory: "queue", name: "myqueue")
        #expect(queue.name == "myqueue")
    }

    @Test("Create element with auto-generated name")
    func createWithAutoName() throws {
        let queue = try Element.make(factory: "queue")
        #expect(!queue.name.isEmpty)
    }

    @Test("Invalid factory throws error")
    func invalidFactory() throws {
        #expect(throws: GStreamerError.self) {
            _ = try Element.make(factory: "nonexistent_element_xyz")
        }
    }

    @Test("Get static pad")
    func getStaticPad() throws {
        let queue = try Element.make(factory: "queue")

        let sinkPad = queue.staticPad("sink")
        #expect(sinkPad != nil)

        let srcPad = queue.staticPad("src")
        #expect(srcPad != nil)

        let invalidPad = queue.staticPad("nonexistent")
        #expect(invalidPad == nil)
    }

    @Test("Link elements")
    func linkElements() throws {
        let src = try Element.make(factory: "videotestsrc")
        let sink = try Element.make(factory: "fakesink")

        let success = src.link(to: sink)
        #expect(success)
    }

    @Test("Add element to pipeline and sync state")
    func addToPipeline() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")

        let queue = try Element.make(factory: "queue", name: "testqueue")
        let added = pipeline.add(queue)
        #expect(added)

        // Find it by name
        let found = pipeline.element(named: "testqueue")
        #expect(found != nil)
    }

    @Test("Request pad from tee")
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
}
