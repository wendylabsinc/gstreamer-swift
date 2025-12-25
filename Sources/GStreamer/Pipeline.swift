import CGStreamer
import CGStreamerShim

/// A GStreamer pipeline for media processing.
///
/// Pipelines are the core abstraction in GStreamer. They define a graph of
/// elements that process media data, from sources through filters to sinks.
///
/// ## Overview
///
/// Create pipelines using the familiar `gst-launch-1.0` syntax. The pipeline
/// parses the description string and creates all necessary elements.
///
/// ## Topics
///
/// ### Creating Pipelines
///
/// - ``init(_:)``
///
/// ### Controlling Playback
///
/// - ``play()``
/// - ``pause()``
/// - ``stop()``
/// - ``setState(_:)``
/// - ``currentState()``
/// - ``State``
///
/// ### Accessing Elements
///
/// - ``element(named:)``
/// - ``appSink(named:)``
///
/// ### Bus Messages
///
/// - ``bus``
///
/// ## Example
///
/// ```swift
/// // Create a simple test pipeline
/// let pipeline = try Pipeline("videotestsrc ! autovideosink")
/// try pipeline.play()
///
/// // Listen for end of stream
/// for await message in pipeline.bus.messages() {
///     if case .eos = message {
///         break
///     }
/// }
///
/// pipeline.stop()
/// ```
///
/// ## Pipeline Syntax
///
/// Pipelines use the `gst-launch-1.0` syntax:
/// - Elements are separated by `!`
/// - Properties use `property=value` syntax
/// - Named elements use `name=identifier`
///
/// ```swift
/// // Simple pipeline
/// let p1 = try Pipeline("videotestsrc ! autovideosink")
///
/// // With caps filter
/// let p2 = try Pipeline("videotestsrc ! video/x-raw,width=640,height=480 ! autovideosink")
///
/// // Named elements for later access
/// let p3 = try Pipeline("videotestsrc name=src ! appsink name=sink")
/// let src = p3.element(named: "src")
/// ```
public final class Pipeline: @unchecked Sendable {

    /// Pipeline playback state.
    ///
    /// Represents the current state of a pipeline. State transitions are
    /// asynchronous and may take time to complete.
    public enum State: Sendable {
        /// Initial state, no resources allocated.
        case null
        /// Resources allocated but not streaming.
        case ready
        /// Pipeline is paused, ready to play.
        case paused
        /// Pipeline is actively streaming.
        case playing

        internal var gstState: GstState {
            switch self {
            case .null: return GST_STATE_NULL
            case .ready: return GST_STATE_READY
            case .paused: return GST_STATE_PAUSED
            case .playing: return GST_STATE_PLAYING
            }
        }

        internal init(gstState: GstState) {
            switch gstState {
            case GST_STATE_NULL: self = .null
            case GST_STATE_READY: self = .ready
            case GST_STATE_PAUSED: self = .paused
            case GST_STATE_PLAYING: self = .playing
            default: self = .null
            }
        }
    }

    /// The underlying GstElement pointer.
    internal let _element: UnsafeMutablePointer<GstElement>

    /// Cached bus instance.
    private var _bus: Bus?

    /// Create a pipeline from a `gst-launch-1.0`-style description string.
    ///
    /// The description uses the same syntax as the `gst-launch-1.0` command-line tool.
    /// Elements are separated by `!` and properties are set using `property=value`.
    ///
    /// - Parameter description: A GStreamer pipeline description.
    /// - Throws: ``GStreamerError/parsePipeline(_:)`` if parsing fails.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Video test pattern to screen
    /// let display = try Pipeline("videotestsrc ! autovideosink")
    ///
    /// // Webcam capture (Linux)
    /// let webcam = try Pipeline("v4l2src device=/dev/video0 ! autovideosink")
    ///
    /// // With format negotiation
    /// let formatted = try Pipeline("""
    ///     videotestsrc ! \
    ///     video/x-raw,format=BGRA,width=1280,height=720 ! \
    ///     appsink name=sink
    ///     """)
    ///
    /// // Audio capture (Linux)
    /// let audio = try Pipeline("alsasrc device=hw:0 ! autoaudiosink")
    /// ```
    public init(_ description: String) throws {
        try GStreamer.ensureInitialized()

        var errorMessage: UnsafeMutablePointer<CChar>?
        guard let pipeline = swift_gst_parse_launch(description, &errorMessage) else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            errorMessage.map { g_free($0) }
            throw GStreamerError.parsePipeline(message)
        }
        errorMessage.map { g_free($0) }
        self._element = pipeline
    }

    deinit {
        _ = swift_gst_element_set_state(_element, GST_STATE_NULL)
        swift_gst_object_unref(_element)
    }

    /// Start the pipeline (set to PLAYING state).
    ///
    /// This begins media processing. Data flows from sources through the pipeline
    /// to sinks. The state change is asynchronous.
    ///
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the state change fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("videotestsrc ! autovideosink")
    /// try pipeline.play()
    /// // Pipeline is now playing
    /// ```
    public func play() throws {
        try setState(.playing)
    }

    /// Pause the pipeline.
    ///
    /// The pipeline stops processing but retains its resources. It can be
    /// resumed by calling ``play()`` again.
    ///
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the state change fails.
    public func pause() throws {
        try setState(.paused)
    }

    /// Stop the pipeline (set to NULL state).
    ///
    /// This stops all processing and releases resources. The pipeline can
    /// be started again with ``play()``.
    public func stop() {
        _ = swift_gst_element_set_state(_element, GST_STATE_NULL)
    }

    /// Set the pipeline to a specific state.
    ///
    /// - Parameter state: The desired state.
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the state change fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try pipeline.setState(.ready)  // Allocate resources
    /// try pipeline.setState(.paused) // Prepare to play
    /// try pipeline.setState(.playing) // Start streaming
    /// ```
    public func setState(_ state: State) throws {
        let result = swift_gst_element_set_state(_element, state.gstState)
        if result == GST_STATE_CHANGE_FAILURE {
            throw GStreamerError.stateChangeFailed
        }
    }

    /// Get the current pipeline state.
    ///
    /// Returns the current state of the pipeline. Note that state changes are
    /// asynchronous, so the returned state may be transitional.
    ///
    /// - Returns: The current pipeline state.
    public func currentState() -> State {
        let state = swift_gst_element_get_state(_element, 0)
        return State(gstState: state)
    }

    /// The pipeline's message bus.
    ///
    /// Use the bus to receive messages about pipeline events like errors,
    /// end-of-stream, and state changes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await message in pipeline.bus.messages(filter: [.eos, .error]) {
    ///     switch message {
    ///     case .eos:
    ///         print("End of stream")
    ///     case .error(let msg, _):
    ///         print("Error: \(msg)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public var bus: Bus {
        if let existingBus = _bus {
            return existingBus
        }
        let gstBus = swift_gst_element_get_bus(_element)!
        let newBus = Bus(bus: gstBus)
        _bus = newBus
        return newBus
    }

    /// Find an element in the pipeline by name.
    ///
    /// Elements are named using `name=identifier` in the pipeline description.
    ///
    /// - Parameter name: The element name.
    /// - Returns: The element, or `nil` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("videotestsrc name=src pattern=0 ! fakesink")
    ///
    /// if let src = pipeline.element(named: "src") {
    ///     src.set("pattern", 1) // Change test pattern
    /// }
    /// ```
    public func element(named name: String) -> Element? {
        guard let el = swift_gst_bin_get_by_name(_element, name) else {
            return nil
        }
        return Element(element: el)
    }

    /// Get an appsink element from the pipeline.
    ///
    /// This is a convenience method for accessing appsink elements used
    /// to pull frames from the pipeline.
    ///
    /// - Parameter name: The appsink element name.
    /// - Returns: An ``AppSink`` wrapper for the element.
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("""
    ///     videotestsrc ! video/x-raw,format=BGRA ! appsink name=sink
    ///     """)
    ///
    /// let sink = try pipeline.appSink(named: "sink")
    /// try pipeline.play()
    ///
    /// for await frame in sink.frames() {
    ///     // Process frame...
    /// }
    /// ```
    public func appSink(named name: String) throws -> AppSink {
        try AppSink(pipeline: self, name: name)
    }
}
