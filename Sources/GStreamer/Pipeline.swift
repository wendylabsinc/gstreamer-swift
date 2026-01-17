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

    // MARK: - Playback Rate

    /// Set the playback rate.
    ///
    /// Use this to speed up, slow down, or reverse playback.
    ///
    /// - Parameter rate: The playback rate. 1.0 = normal, 2.0 = 2x speed,
    ///   0.5 = half speed, -1.0 = reverse.
    /// - Throws: ``GStreamerError/seekFailed(position:)`` if the rate change fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fast forward at 2x speed
    /// try pipeline.setRate(2.0)
    ///
    /// // Slow motion at half speed
    /// try pipeline.setRate(0.5)
    ///
    /// // Reverse playback
    /// try pipeline.setRate(-1.0)
    ///
    /// // Return to normal speed
    /// try pipeline.setRate(1.0)
    /// ```
    public func setRate(_ rate: Double) throws {
        var currentPosition: gint64 = 0
        gst_element_query_position(_element, GST_FORMAT_TIME, &currentPosition)

        let flags = GST_SEEK_FLAG_FLUSH.rawValue | GST_SEEK_FLAG_ACCURATE.rawValue
        let seekFlags = GstSeekFlags(rawValue: UInt32(flags))

        let success: gboolean
        if rate >= 0 {
            success = gst_element_seek(
                _element,
                rate,
                GST_FORMAT_TIME,
                seekFlags,
                GST_SEEK_TYPE_SET,
                currentPosition,
                GST_SEEK_TYPE_NONE,
                0
            )
        } else {
            // Reverse playback - seek from 0 to current position
            success = gst_element_seek(
                _element,
                rate,
                GST_FORMAT_TIME,
                seekFlags,
                GST_SEEK_TYPE_SET,
                0,
                GST_SEEK_TYPE_SET,
                currentPosition
            )
        }

        guard success != 0 else {
            throw GStreamerError.seekFailed(position: UInt64(max(0, currentPosition)))
        }
    }

    /// Get the current playback rate.
    ///
    /// - Returns: The current playback rate (1.0 = normal speed).
    public var rate: Double {
        let query = gst_query_new_segment(GST_FORMAT_TIME)
        defer { gst_query_unref(query) }

        var rate: gdouble = 1.0
        if gst_element_query(_element, query) != 0 {
            gst_query_parse_segment(query, &rate, nil, nil, nil)
        }
        return rate
    }

    /// Step forward or backward by a specified amount.
    ///
    /// - Parameters:
    ///   - amount: Amount to step (frames for video, samples for audio).
    ///   - format: The format of the step amount.
    ///   - rate: Step rate (negative for backward).
    ///   - flush: Whether to flush the pipeline.
    /// - Returns: `true` if the step was successful.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Step forward 1 frame
    /// pipeline.step(amount: 1, format: .buffers)
    ///
    /// // Step forward 1 second of time
    /// pipeline.step(amount: 1_000_000_000, format: .time)
    /// ```
    @discardableResult
    public func step(amount: UInt64, format: StepFormat = .buffers, rate: Double = 1.0, flush: Bool = true) -> Bool {
        let event = gst_event_new_step(format.gstFormat, amount, rate, flush ? 1 : 0, 0)
        return gst_element_send_event(_element, event) != 0
    }

    /// Format for step operations.
    public enum StepFormat: Sendable {
        case buffers
        case time

        var gstFormat: GstFormat {
            switch self {
            case .buffers: return GST_FORMAT_BUFFERS
            case .time: return GST_FORMAT_TIME
            }
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

    // MARK: - Debugging

    /// Generate a DOT graph representation of the pipeline.
    ///
    /// This creates a Graphviz DOT format string that can be visualized
    /// using `dot` command or online viewers.
    ///
    /// - Parameter details: Level of detail to include in the graph.
    /// - Returns: DOT format string, or `nil` if generation failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let dot = pipeline.generateDotGraph() {
    ///     print(dot)
    ///     // Or save to file:
    ///     try dot.write(toFile: "pipeline.dot", atomically: true, encoding: .utf8)
    /// }
    /// ```
    ///
    /// To visualize, use the `dot` command:
    /// ```bash
    /// dot -Tpng pipeline.dot -o pipeline.png
    /// ```
    public func generateDotGraph(details: DebugGraphDetails = .all) -> String? {
        GLibString.takeOwnership(swift_gst_debug_bin_to_dot_data(_element, details.gstDetails))
    }

    /// Level of detail for debug graph generation.
    public struct DebugGraphDetails: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Show media type on edges.
        public static let mediaCaps = DebugGraphDetails(rawValue: 1 << 0)
        /// Show caps full details.
        public static let capsDetails = DebugGraphDetails(rawValue: 1 << 1)
        /// Show non-default parameters.
        public static let nonDefaultParams = DebugGraphDetails(rawValue: 1 << 2)
        /// Show states of elements.
        public static let states = DebugGraphDetails(rawValue: 1 << 3)
        /// Show full parameter values.
        public static let fullParams = DebugGraphDetails(rawValue: 1 << 4)
        /// Show all details.
        public static let all = DebugGraphDetails(rawValue: UInt32(bitPattern: swift_gst_debug_graph_show_all().rawValue))

        var gstDetails: GstDebugGraphDetails {
            GstDebugGraphDetails(rawValue: Int32(bitPattern: rawValue))
        }
    }

    /// Get the number of elements in this pipeline.
    public var elementCount: Int {
        guard swift_gst_is_bin(_element) != 0 else { return 0 }
        return Int(swift_gst_as_bin(_element).pointee.numchildren)
    }

    // MARK: - Event Sending

    /// Send an EOS (end-of-stream) event to the pipeline.
    ///
    /// This signals to all elements that no more data will be sent.
    /// Use this to gracefully end a pipeline.
    ///
    /// - Returns: `true` if the event was sent successfully.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // After pushing all data to an appsrc pipeline
    /// pipeline.sendEOS()
    ///
    /// // Wait for EOS to propagate
    /// await pipeline.bus.waitForEOS()
    /// ```
    @discardableResult
    public func sendEOS() -> Bool {
        let event = gst_event_new_eos()
        return gst_element_send_event(_element, event) != 0
    }

    /// Send a flush start event to the pipeline.
    ///
    /// This starts a flush operation, telling elements to drop data
    /// and not accept new data until flush stop is sent.
    ///
    /// - Returns: `true` if the event was sent successfully.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Perform a flush (e.g., during seek)
    /// pipeline.sendFlushStart()
    /// // ... reconfigure pipeline ...
    /// pipeline.sendFlushStop()
    /// ```
    @discardableResult
    public func sendFlushStart() -> Bool {
        let event = gst_event_new_flush_start()
        return gst_element_send_event(_element, event) != 0
    }

    /// Send a flush stop event to the pipeline.
    ///
    /// This ends a flush operation, allowing elements to accept data again.
    ///
    /// - Parameter resetTime: Whether to reset the running time.
    /// - Returns: `true` if the event was sent successfully.
    @discardableResult
    public func sendFlushStop(resetTime: Bool = true) -> Bool {
        let event = gst_event_new_flush_stop(resetTime ? 1 : 0)
        return gst_element_send_event(_element, event) != 0
    }

    /// Recalculate and redistribute latency.
    ///
    /// Call this after adding or removing elements that may affect latency.
    ///
    /// - Returns: `true` if successful.
    @discardableResult
    public func recalculateLatency() -> Bool {
        gst_element_send_event(_element, gst_event_new_latency(0)) != 0
    }

    /// Send a custom event to the pipeline.
    ///
    /// This allows sending application-specific events through the pipeline.
    ///
    /// - Parameters:
    ///   - name: The event name/structure name.
    ///   - direction: The event direction.
    /// - Returns: `true` if the event was sent successfully.
    @discardableResult
    public func sendCustomEvent(name: String, direction: EventDirection = .downstream) -> Bool {
        let structure = gst_structure_new_empty(name)
        let eventType: GstEventType
        switch direction {
        case .downstream:
            eventType = GST_EVENT_CUSTOM_DOWNSTREAM
        case .upstream:
            eventType = GST_EVENT_CUSTOM_UPSTREAM
        case .both:
            eventType = GST_EVENT_CUSTOM_BOTH
        }
        let event = gst_event_new_custom(eventType, structure)
        return gst_element_send_event(_element, event) != 0
    }

    /// Direction for custom events.
    public enum EventDirection: Sendable {
        case downstream
        case upstream
        case both
    }

    // MARK: - Clock Access

    /// Get the current clock time of the pipeline.
    ///
    /// This returns the current time according to the pipeline's clock.
    ///
    /// - Returns: The current clock time in nanoseconds, or nil if no clock.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let clockTime = pipeline.clockTime {
    ///     let seconds = Double(clockTime) / 1_000_000_000.0
    ///     print("Clock time: \(seconds)s")
    /// }
    /// ```
    public var clockTime: UInt64? {
        guard let clock = gst_element_get_clock(_element) else {
            return nil
        }
        defer { gst_object_unref(clock) }
        let time = gst_clock_get_time(clock)
        return swift_gst_clock_time_is_valid(time) != 0 ? UInt64(time) : nil
    }

    /// Get the base time of the pipeline.
    ///
    /// The base time is the time when the pipeline started playing.
    /// Use this to calculate running time.
    ///
    /// - Returns: The base time in nanoseconds.
    public var baseTime: UInt64 {
        UInt64(gst_element_get_base_time(_element))
    }

    /// Set the base time of the pipeline.
    ///
    /// - Parameter time: The base time in nanoseconds.
    public func setBaseTime(_ time: UInt64) {
        gst_element_set_base_time(_element, GstClockTime(time))
    }

    /// Get the running time of the pipeline.
    ///
    /// Running time is the time since the pipeline started playing,
    /// calculated as clockTime - baseTime.
    ///
    /// - Returns: The running time in nanoseconds, or nil if unavailable.
    public var runningTime: UInt64? {
        guard let clock = clockTime else { return nil }
        let base = baseTime
        return clock > base ? clock - base : 0
    }

    /// Get the start time of the pipeline.
    ///
    /// The start time is used to calculate the running time of the pipeline.
    ///
    /// - Returns: The start time in nanoseconds.
    public var startTime: UInt64 {
        UInt64(gst_element_get_start_time(_element))
    }

    /// Set the start time of the pipeline.
    ///
    /// - Parameter time: The start time in nanoseconds.
    public func setStartTime(_ time: UInt64) {
        gst_element_set_start_time(_element, GstClockTime(time))
    }

    /// Get the pipeline latency.
    ///
    /// Returns the latency configured on the pipeline.
    ///
    /// - Returns: The latency in nanoseconds, or nil if not available.
    public var latency: UInt64? {
        guard swift_gst_is_pipeline(_element) != 0 else { return nil }
        let lat = gst_pipeline_get_latency(swift_gst_as_pipeline(_element))
        return swift_gst_clock_time_is_valid(lat) != 0 ? UInt64(lat) : nil
    }

    /// Set the pipeline latency.
    ///
    /// This sets a fixed latency for the pipeline. Usually you want to
    /// let GStreamer calculate this automatically.
    ///
    /// - Parameter latency: The latency in nanoseconds.
    public func setLatency(_ latency: UInt64) {
        guard swift_gst_is_pipeline(_element) != 0 else { return }
        gst_pipeline_set_latency(swift_gst_as_pipeline(_element), GstClockTime(latency))
    }

    /// Get the pipeline delay (additional fixed delay).
    ///
    /// - Returns: The delay in nanoseconds.
    public var delay: UInt64 {
        guard swift_gst_is_pipeline(_element) != 0 else { return 0 }
        return UInt64(gst_pipeline_get_delay(swift_gst_as_pipeline(_element)))
    }

    /// Set the pipeline delay.
    ///
    /// This adds a fixed delay to the pipeline latency.
    ///
    /// - Parameter delay: The delay in nanoseconds.
    public func setDelay(_ delay: UInt64) {
        guard swift_gst_is_pipeline(_element) != 0 else { return }
        gst_pipeline_set_delay(swift_gst_as_pipeline(_element), GstClockTime(delay))
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
