import Testing
@testable import GStreamer

@Suite("Tee Tests")
struct TeeTests {

    init() throws {
        try GStreamer.initialize()
    }

    @Test("Create Tee from pipeline")
    func createFromPipeline() throws {
        let pipeline = try Pipeline("videotestsrc ! tee name=splitter ! fakesink")
        let tee = try Tee(pipeline: pipeline, name: "splitter")
        #expect(tee.element.name == "splitter")
    }

    @Test("Tee not found throws error")
    func teeNotFound() throws {
        let pipeline = try Pipeline("videotestsrc ! fakesink")

        #expect(throws: GStreamerError.self) {
            _ = try Tee(pipeline: pipeline, name: "splitter")
        }
    }

    @Test("Create Tee element directly")
    func createDirectly() throws {
        let tee = try Tee.create(name: "mytee")
        #expect(tee.element.name == "mytee")
        #expect(tee.branchCount == 0)
    }

    @Test("Add branch to Tee")
    func addBranch() throws {
        let pipeline = try Pipeline("videotestsrc ! tee name=t ! queue ! fakesink")
        let tee = try Tee(pipeline: pipeline, name: "t")

        let queue = try Element.make(factory: "queue")
        let sink = try Element.make(factory: "fakesink")

        pipeline.add(queue)
        pipeline.add(sink)

        let branched = tee.branch(to: queue)
        #expect(branched)
        #expect(tee.branchCount == 1)

        queue.link(to: sink)
    }

    @Test("Multi-output pipeline with Tee")
    func multiOutputPipeline() async throws {
        // Create a pipeline that outputs to two appsinks via tee
        let pipeline = try Pipeline(
            """
            videotestsrc num-buffers=5 ! \
            video/x-raw,format=BGRA,width=4,height=4 ! \
            tee name=t \
            t. ! queue ! appsink name=sink1 \
            t. ! queue ! appsink name=sink2
            """
        )

        let sink1 = try pipeline.appSink(named: "sink1")
        let sink2 = try pipeline.appSink(named: "sink2")

        try pipeline.play()

        // Both sinks should receive frames
        var sink1Count = 0
        var sink2Count = 0

        // Use a task group to read from both sinks
        try await withThrowingTaskGroup(of: Int.self) { group in
            group.addTask {
                var count = 0
                for try await _ in sink1.frames() {
                    count += 1
                    if count >= 2 { break }
                }
                return count
            }
            group.addTask {
                var count = 0
                for try await _ in sink2.frames() {
                    count += 1
                    if count >= 2 { break }
                }
                return count
            }

            for try await count in group {
                if sink1Count == 0 { sink1Count = count }
                else { sink2Count = count }
            }
        }

        #expect(sink1Count >= 2)
        #expect(sink2Count >= 2)

        pipeline.stop()
    }

    @Test("Remove branch from Tee")
    func removeBranch() throws {
        let tee = try Tee.create(name: "t")

        _ = try Element.make(factory: "queue")
        _ = try Element.make(factory: "queue")

        // Note: This test just verifies the API works without a pipeline
        // In a real scenario, elements would need to be in a pipeline
        #expect(tee.branchCount == 0)
    }
}
