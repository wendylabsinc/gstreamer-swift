import CGStreamer
import CGStreamerShim
import Synchronization

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
/// - ``appSource(named:)``
/// - ``audioSink(named:)``
///
/// ### Position and Duration
///
/// - ``position``
/// - ``duration``
///
/// ### Seeking
///
/// - ``seek(to:)``
/// - ``seek(to:flags:)``
/// - ``SeekFlags``
///
/// ### Dynamic Pipeline
///
/// - ``add(_:)``
/// - ``remove(_:)``
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
///
/// ## Thread Safety
///
/// Pipeline is marked as `@unchecked Sendable` because it wraps a GStreamer C pointer
/// which has its own internal thread safety guarantees. GStreamer's core is thread-safe
/// for most operations, but some concurrent modifications may require external
/// synchronization. The cached bus instance uses a `Mutex` for thread-safe access.
///
/// - Note: While the Pipeline can be safely passed between isolation domains,
///   concurrent modifications to element properties should be avoided or externally
///   synchronized.
public final class Pipeline: @unchecked Sendable {

    /// Pipeline playback state.
    ///
    /// Represents the current state of a pipeline. State transitions are
    /// asynchronous and may take time to complete.
    public enum State: Sendable, CustomStringConvertible {
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

        /// A human-readable description of the state.
        public var description: String {
            switch self {
            case .null: return "null"
            case .ready: return "ready"
            case .paused: return "paused"
            case .playing: return "playing"
            }
        }
    }

    /// The underlying GstElement pointer.
    internal let _element: UnsafeMutablePointer<GstElement>

    /// Cached bus instance (thread-safe access).
    private let _bus = Mutex<Bus?>(nil)

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
            let message = GLibString.takeOwnership(errorMessage) ?? "Unknown error"
            throw GStreamerError.parsePipeline(message)
        }
        _ = GLibString.takeOwnership(errorMessage)  // Free if non-nil
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
        let currentState = self.currentState()
        let result = swift_gst_element_set_state(_element, state.gstState)
        if result == GST_STATE_CHANGE_FAILURE {
            throw GStreamerError.stateChangeFailed(element: nil, from: currentState, to: state)
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
        _bus.withLock { cachedBus in
            if let existingBus = cachedBus {
                return existingBus
            }
            guard let gstBus = swift_gst_element_get_bus(_element) else {
                preconditionFailure("Pipeline must have a bus")
            }
            let newBus = Bus(bus: gstBus)
            cachedBus = newBus
            return newBus
        }
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

    /// Get an appsrc element from the pipeline.
    ///
    /// This is a convenience method for accessing appsrc elements used
    /// to push data into the pipeline.
    ///
    /// - Parameter name: The appsrc element name.
    /// - Returns: An ``AppSource`` wrapper for the element.
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if not found.
    public func appSource(named name: String) throws -> AppSource {
        try AppSource(pipeline: self, name: name)
    }

    /// Get an audio appsink element from the pipeline.
    ///
    /// This is a convenience method for accessing appsink elements used
    /// to pull audio buffers from the pipeline.
    ///
    /// - Parameter name: The appsink element name.
    /// - Returns: An ``AudioSink`` wrapper for the element.
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if not found.
    public func audioSink(named name: String) throws -> AudioSink {
        try AudioSink(pipeline: self, name: name)
    }

    // MARK: - Position and Duration

    /// The current playback position in nanoseconds.
    ///
    /// Returns `nil` if the position cannot be queried (e.g., pipeline not playing).
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let pos = pipeline.position {
    ///     let seconds = Double(pos) / 1_000_000_000.0
    ///     print("Position: \(seconds)s")
    /// }
    /// ```
    public var position: UInt64? {
        var pos: gint64 = 0
        guard swift_gst_element_query_position(_element, &pos) != 0 else {
            return nil
        }
        return pos >= 0 ? UInt64(pos) : nil
    }

    /// The total duration in nanoseconds.
    ///
    /// Returns `nil` if the duration cannot be queried (e.g., live stream).
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let dur = pipeline.duration {
    ///     let seconds = Double(dur) / 1_000_000_000.0
    ///     print("Duration: \(seconds)s")
    /// }
    /// ```
    public var duration: UInt64? {
        var dur: gint64 = 0
        guard swift_gst_element_query_duration(_element, &dur) != 0 else {
            return nil
        }
        return dur >= 0 ? UInt64(dur) : nil
    }

    // MARK: - Seeking

    /// Flags for seek operations.
    ///
    /// Combine flags to control seek behavior.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Accurate seek (slower but precise)
    /// try pipeline.seek(to: position, flags: [.flush, .accurate])
    ///
    /// // Fast seek to keyframe
    /// try pipeline.seek(to: position, flags: [.flush, .keyUnit])
    /// ```
    public struct SeekFlags: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Flush the pipeline before seeking.
        ///
        /// This discards any buffered data and provides immediate seeking.
        /// Almost always desired for interactive seeking.
        public static let flush = SeekFlags(rawValue: UInt32(swift_gst_seek_flag_flush().rawValue))

        /// Seek to the nearest keyframe.
        ///
        /// Faster but may not be frame-accurate. Good for scrubbing.
        public static let keyUnit = SeekFlags(rawValue: UInt32(swift_gst_seek_flag_key_unit().rawValue))

        /// Seek to the exact position.
        ///
        /// Slower but frame-accurate. Requires decoding from previous keyframe.
        public static let accurate = SeekFlags(rawValue: UInt32(swift_gst_seek_flag_accurate().rawValue))

        internal var gstFlags: GstSeekFlags {
            GstSeekFlags(rawValue: rawValue)
        }
    }

    /// Seek to a position in nanoseconds.
    ///
    /// This performs a flush seek with keyframe alignment for fast response.
    ///
    /// - Parameter position: The target position in nanoseconds.
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the seek fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Seek to 10 seconds
    /// try pipeline.seek(to: 10_000_000_000)
    ///
    /// // Seek to 30% of duration
    /// if let duration = pipeline.duration {
    ///     try pipeline.seek(to: duration * 30 / 100)
    /// }
    /// ```
    public func seek(to position: UInt64) throws {
        guard swift_gst_element_seek_simple(_element, gint64(position)) != 0 else {
            throw GStreamerError.seekFailed(position: position)
        }
    }

    /// Seek to a position with custom flags.
    ///
    /// - Parameters:
    ///   - position: The target position in nanoseconds.
    ///   - flags: Seek flags controlling the behavior.
    /// - Throws: ``GStreamerError/stateChangeFailed`` if the seek fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Accurate seek for frame-by-frame navigation
    /// try pipeline.seek(to: framePosition, flags: [.flush, .accurate])
    ///
    /// // Fast keyframe seek for scrubbing
    /// try pipeline.seek(to: scrubPosition, flags: [.flush, .keyUnit])
    /// ```
    public func seek(to position: UInt64, flags: SeekFlags) throws {
        guard swift_gst_element_seek(_element, 1.0, gint64(position), -1, flags.gstFlags) != 0 else {
            throw GStreamerError.seekFailed(position: position)
        }
    }

    // MARK: - Dynamic Pipeline

    /// Add an element to the pipeline.
    ///
    /// The element must be created separately and will be added to this pipeline.
    ///
    /// - Parameter element: The element to add.
    /// - Returns: `true` if successful.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let element = try Element.make(factory: "queue", name: "myqueue")
    /// pipeline.add(element)
    /// element.syncStateWithParent()
    /// ```
    @discardableResult
    public func add(_ element: Element) -> Bool {
        swift_gst_bin_add(_element, element.element) != 0
    }

    /// Remove an element from the pipeline.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: `true` if successful.
    @discardableResult
    public func remove(_ element: Element) -> Bool {
        swift_gst_bin_remove(_element, element.element) != 0
    }

    // MARK: - Resource Management

    /// Execute a closure with a pipeline that is automatically stopped on exit.
    ///
    /// This method provides automatic resource cleanup, ensuring the pipeline
    /// is stopped when the closure exits, even if an error is thrown.
    ///
    /// - Parameters:
    ///   - description: The pipeline description string.
    ///   - body: A closure that receives the pipeline.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error from pipeline creation or the closure.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Pipeline is automatically stopped when the closure exits
    /// try await Pipeline.withPipeline("videotestsrc ! autovideosink") { pipeline in
    ///     try pipeline.play()
    ///     await pipeline.bus.waitForEOS()
    /// }
    ///
    /// // Also works with throwing closures
    /// let frameCount = try await Pipeline.withPipeline("""
    ///     videotestsrc num-buffers=100 ! appsink name=sink
    ///     """) { pipeline in
    ///     let sink = try pipeline.appSink(named: "sink")
    ///     try pipeline.play()
    ///
    ///     var count = 0
    ///     for try await _ in sink.frames() {
    ///         count += 1
    ///     }
    ///     return count
    /// }
    /// ```
    public static func withPipeline<R>(
        _ description: String,
        _ body: (Pipeline) async throws -> R
    ) async throws -> R {
        let pipeline = try Pipeline(description)
        defer {
            pipeline.stop()
        }
        return try await body(pipeline)
    }

    /// Execute a synchronous closure with a pipeline that is automatically stopped on exit.
    ///
    /// - Parameters:
    ///   - description: The pipeline description string.
    ///   - body: A closure that receives the pipeline.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error from pipeline creation or the closure.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try Pipeline.withPipeline("videotestsrc ! fakesink") { pipeline in
    ///     try pipeline.play()
    ///     // Do some work...
    /// }
    /// // Pipeline is automatically stopped here
    /// ```
    public static func withPipeline<R>(
        _ description: String,
        _ body: (Pipeline) throws -> R
    ) throws -> R {
        let pipeline = try Pipeline(description)
        defer {
            pipeline.stop()
        }
        return try body(pipeline)
    }
}
