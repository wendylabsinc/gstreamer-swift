import CGStreamer
import CGStreamerShim

/// A helper for splitting a stream to multiple destinations.
///
/// Tee allows you to send the same stream to multiple sinks simultaneously.
/// Common use cases include:
/// - Display + recording
/// - Display + ML inference
/// - Multiple network outputs
///
/// ## Overview
///
/// Create a pipeline with a tee element, then use ``branch(to:)`` to add
/// destinations. Each branch receives an independent copy of the data.
///
/// ## Topics
///
/// ### Creating Branches
///
/// - ``branch(to:)``
/// - ``branchCount``
///
/// ## Example
///
/// ```swift
/// // Create pipeline with tee
/// let pipeline = try Pipeline("""
///     videotestsrc ! tee name=t \
///     t. ! queue ! autovideosink \
///     t. ! queue ! appsink name=sink
///     """)
/// ```
///
/// ## Dynamic Branching
///
/// ```swift
/// // Create tee for dynamic branching
/// let pipeline = try Pipeline("videotestsrc ! tee name=t ! queue ! fakesink")
/// let tee = try Tee(pipeline: pipeline, name: "t")
///
/// // Add a recording branch
/// let recorder = try Element.make(factory: "filesink", name: "recorder")
/// recorder.set("location", "output.raw")
/// let queue1 = try Element.make(factory: "queue")
///
/// pipeline.add(queue1)
/// pipeline.add(recorder)
///
/// tee.branch(to: queue1)
/// queue1.link(to: recorder)
///
/// queue1.syncStateWithParent()
/// recorder.syncStateWithParent()
/// ```
///
/// ## Multi-Output Example
///
/// ```swift
/// // Webcam to display + ML + recording
/// let pipeline = try Pipeline("""
///     v4l2src device=/dev/video0 ! \
///     videoconvert ! tee name=t \
///     t. ! queue ! autovideosink \
///     t. ! queue ! video/x-raw,format=BGRA ! appsink name=ml \
///     t. ! queue ! x264enc ! mp4mux ! filesink location=recording.mp4
///     """)
///
/// let mlSink = try pipeline.appSink(named: "ml")
/// try pipeline.play()
///
/// // Process frames for ML while displaying and recording
/// for await frame in mlSink.frames() {
///     try frame.withMappedBytes { span in
///         // Run inference...
///     }
/// }
/// ```
public final class Tee: @unchecked Sendable {
    /// The tee element.
    public let element: Element

    /// Tracks requested pads for cleanup.
    private var requestedPads: [Pad] = []

    /// Create a Tee wrapper from a pipeline by element name.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline containing the tee.
    ///   - name: The name of the tee element.
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("videotestsrc ! tee name=splitter ! fakesink")
    /// let tee = try Tee(pipeline: pipeline, name: "splitter")
    /// ```
    public init(pipeline: Pipeline, name: String) throws {
        guard let element = pipeline.element(named: name) else {
            throw GStreamerError.elementNotFound(name)
        }
        self.element = element
    }

    /// Create a new Tee element.
    ///
    /// - Parameter name: Optional name for the element.
    /// - Returns: A new Tee element.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let tee = try Tee.create(name: "splitter")
    /// pipeline.add(tee.element)
    /// source.link(to: tee.element)
    /// ```
    public static func create(name: String? = nil) throws -> Tee {
        let el = try Element.make(factory: "tee", name: name)
        return Tee(element: el)
    }

    private init(element: Element) {
        self.element = element
    }

    /// The number of active branches.
    public var branchCount: Int {
        requestedPads.count
    }

    /// Create a new branch to an element.
    ///
    /// This requests a new source pad from the tee and links it to the
    /// sink pad of the target element.
    ///
    /// - Parameter target: The element to receive this branch.
    /// - Returns: `true` if the branch was created successfully.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let queue = try Element.make(factory: "queue")
    /// let sink = try Element.make(factory: "fakesink")
    ///
    /// pipeline.add(queue)
    /// pipeline.add(sink)
    ///
    /// tee.branch(to: queue)
    /// queue.link(to: sink)
    ///
    /// queue.syncStateWithParent()
    /// sink.syncStateWithParent()
    /// ```
    @discardableResult
    public func branch(to target: Element) -> Bool {
        guard let srcPad = element.requestPad("src_%u"),
              let sinkPad = target.staticPad("sink") else {
            return false
        }

        let success = srcPad.link(to: sinkPad)
        if success {
            requestedPads.append(srcPad)
        }
        return success
    }

    /// Remove a branch and release its pad.
    ///
    /// - Parameter index: The index of the branch to remove.
    public func removeBranch(at index: Int) {
        guard index >= 0 && index < requestedPads.count else { return }
        let pad = requestedPads.remove(at: index)
        element.releasePad(pad)
    }

    /// Remove all branches.
    public func removeAllBranches() {
        for pad in requestedPads {
            element.releasePad(pad)
        }
        requestedPads.removeAll()
    }
}
