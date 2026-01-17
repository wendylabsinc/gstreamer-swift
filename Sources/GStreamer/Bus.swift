import CGStreamer
import CGStreamerShim

/// Messages received from the GStreamer pipeline bus.
///
/// BusMessage represents various events that can occur during pipeline execution.
/// Use pattern matching to handle different message types.
///
/// ## Overview
///
/// Messages are delivered through the ``Bus/messages(filter:)`` async stream.
/// Each message type provides relevant information about the event.
///
/// ## Topics
///
/// ### Message Types
///
/// - ``eos``
/// - ``error(message:debug:)``
/// - ``warning(message:debug:)``
/// - ``stateChanged(old:new:)``
/// - ``element(name:fields:)``
///
/// ## Example
///
/// ```swift
/// for await message in pipeline.bus.messages() {
///     switch message {
///     case .eos:
///         print("Stream ended")
///     case .error(let msg, let debug):
///         print("Error: \(msg)")
///         if let debug { print("Debug: \(debug)") }
///     case .stateChanged(let old, let new):
///         print("State: \(old) → \(new)")
///     default:
///         break
///     }
/// }
/// ```
public enum BusMessage: Sendable {
    /// End of stream reached.
    ///
    /// This message indicates that all data has been processed. For live sources
    /// like webcams, EOS typically only occurs when the pipeline is stopped.
    case eos

    /// An error occurred in the pipeline.
    ///
    /// - Parameters:
    ///   - message: A human-readable error description.
    ///   - debug: Optional detailed debug information.
    ///
    /// ## Example
    ///
    /// ```swift
    /// case .error(let message, let debug):
    ///     print("Pipeline error: \(message)")
    ///     if let debug {
    ///         // Debug info often contains file/line info
    ///         print("Debug: \(debug)")
    ///     }
    /// ```
    case error(message: String, debug: String?)

    /// A warning occurred in the pipeline.
    ///
    /// Warnings don't stop the pipeline but indicate potential issues.
    ///
    /// - Parameters:
    ///   - message: A human-readable warning description.
    ///   - debug: Optional detailed debug information.
    case warning(message: String, debug: String?)

    /// The pipeline state changed.
    ///
    /// State changes are asynchronous. This message is sent when a state
    /// transition completes.
    ///
    /// - Parameters:
    ///   - old: The previous state.
    ///   - new: The new current state.
    ///
    /// ## Example
    ///
    /// ```swift
    /// case .stateChanged(let old, let new):
    ///     if new == .playing {
    ///         print("Pipeline is now playing")
    ///     }
    /// ```
    case stateChanged(old: Pipeline.State, new: Pipeline.State)

    /// An element-specific message.
    ///
    /// Custom messages from pipeline elements. The content depends on
    /// the specific element.
    ///
    /// - Parameters:
    ///   - name: The element name that sent the message.
    ///   - fields: Key-value pairs of message data.
    case element(name: String, fields: [String: String])

    /// Buffering status changed.
    ///
    /// This message is posted when buffering status changes.
    /// When percent reaches 100, buffering is complete.
    ///
    /// - Parameter percent: Buffering percentage (0-100).
    case buffering(percent: Int)

    /// Duration changed notification.
    ///
    /// Posted when the stream duration has changed and should be re-queried.
    case durationChanged

    /// Latency notification.
    ///
    /// Posted when latency should be recalculated.
    case latency

    /// Tag/metadata received.
    ///
    /// Posted when stream metadata (tags) are found.
    ///
    /// - Parameter tags: String representation of the tags.
    case tag(String)

    /// Quality of service notification.
    ///
    /// Posted when QoS events occur (frames dropped, etc.).
    ///
    /// - Parameters:
    ///   - live: Whether this is from a live source.
    ///   - runningTime: Running time when QoS was generated.
    ///   - streamTime: Stream time when QoS was generated.
    case qos(live: Bool, runningTime: UInt64, streamTime: UInt64)

    /// Stream start notification.
    ///
    /// Posted when a new stream starts.
    case streamStart

    /// Clock lost notification.
    ///
    /// Posted when the clock being used becomes unusable.
    case clockLost

    /// New clock selected.
    ///
    /// Posted when a new clock was selected.
    case newClock

    /// Progress notification.
    ///
    /// Posted for progress updates from elements.
    ///
    /// - Parameters:
    ///   - type: The progress type.
    ///   - code: Progress code.
    ///   - text: Human-readable progress text.
    case progress(type: ProgressType, code: String, text: String)

    /// Progress notification types.
    public enum ProgressType: Int32, Sendable {
        case start = 0
        case `continue` = 1
        case complete = 2
        case cancelled = 3
        case error = 4
        case unknown = -1
    }

    /// An info message from an element.
    ///
    /// - Parameters:
    ///   - message: A human-readable info message.
    ///   - debug: Optional debug information.
    case info(message: String, debug: String?)
}

// MARK: - CustomStringConvertible

extension BusMessage: CustomStringConvertible {
    /// A human-readable description of the bus message.
    public var description: String {
        switch self {
        case .eos:
            return "BusMessage.eos"
        case .error(let message, let debug):
            var result = "BusMessage.error: \(message)"
            if let debug {
                result += "\n  Debug: \(debug)"
            }
            return result
        case .warning(let message, let debug):
            var result = "BusMessage.warning: \(message)"
            if let debug {
                result += "\n  Debug: \(debug)"
            }
            return result
        case .stateChanged(let old, let new):
            return "BusMessage.stateChanged: \(old) → \(new)"
        case .element(let name, let fields):
            if fields.isEmpty {
                return "BusMessage.element(\(name))"
            } else {
                let fieldsStr = fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                return "BusMessage.element(\(name): \(fieldsStr))"
            }
        case .buffering(let percent):
            return "BusMessage.buffering(\(percent)%)"
        case .durationChanged:
            return "BusMessage.durationChanged"
        case .latency:
            return "BusMessage.latency"
        case .tag(let tags):
            return "BusMessage.tag: \(tags)"
        case .qos(let live, let runningTime, let streamTime):
            return "BusMessage.qos(live: \(live), running: \(runningTime), stream: \(streamTime))"
        case .streamStart:
            return "BusMessage.streamStart"
        case .clockLost:
            return "BusMessage.clockLost"
        case .newClock:
            return "BusMessage.newClock"
        case .progress(let type, let code, let text):
            return "BusMessage.progress(\(type): \(code) - \(text))"
        case .info(let message, let debug):
            var result = "BusMessage.info: \(message)"
            if let debug {
                result += "\n  Debug: \(debug)"
            }
            return result
        }
    }
}

/// A GStreamer bus for receiving messages from a pipeline.
///
/// The bus provides an async stream of messages that can be used to monitor
/// pipeline state, handle errors, and detect end-of-stream conditions.
///
/// ## Overview
///
/// Every pipeline has a bus that delivers messages about events occurring
/// in the pipeline. Use ``messages(filter:)`` to receive messages as an
/// async stream.
///
/// ## Topics
///
/// ### Receiving Messages
///
/// - ``messages(filter:)``
/// - ``Filter``
///
/// ## Example
///
/// ```swift
/// let pipeline = try Pipeline("videotestsrc num-buffers=100 ! fakesink")
/// try pipeline.play()
///
/// // Wait for end of stream
/// for await message in pipeline.bus.messages(filter: [.eos, .error]) {
///     switch message {
///     case .eos:
///         print("Done!")
///         break
///     case .error(let msg, _):
///         print("Error: \(msg)")
///         break
///     default:
///         continue
///     }
/// }
///
/// pipeline.stop()
/// ```
///
/// ## Filtering Messages
///
/// Use the filter parameter to receive only specific message types:
///
/// ```swift
/// // Only receive errors and EOS
/// for await message in pipeline.bus.messages(filter: [.error, .eos]) {
///     // Handle filtered messages
/// }
///
/// // Track state changes
/// for await message in pipeline.bus.messages(filter: [.stateChanged]) {
///     if case .stateChanged(_, let new) = message {
///         print("New state: \(new)")
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// Bus is marked as `@unchecked Sendable` because it wraps a GStreamer C pointer.
/// GStreamer's bus is internally thread-safe for posting and receiving messages.
/// The async stream returned by ``messages(filter:)`` uses `Task.detached` with
/// proper cancellation handling for safe concurrent access.
public final class Bus: @unchecked Sendable {
    /// Filter for bus messages.
    ///
    /// Use this to specify which message types to receive from the bus.
    /// Filters are combined using set operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Single filter
    /// let filter: Bus.Filter = .error
    ///
    /// // Multiple filters
    /// let filters: Bus.Filter = [.error, .eos, .warning]
    ///
    /// for await message in pipeline.bus.messages(filter: filters) {
    ///     // Only receive error, eos, and warning messages
    /// }
    /// ```
    public struct Filter: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Filter for error messages.
        public static let error = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_ERROR.rawValue))

        /// Filter for warning messages.
        public static let warning = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_WARNING.rawValue))

        /// Filter for end-of-stream messages.
        public static let eos = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_EOS.rawValue))

        /// Filter for state change messages.
        public static let stateChanged = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_STATE_CHANGED.rawValue))

        /// Filter for element-specific messages.
        public static let element = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_ELEMENT.rawValue))

        /// Filter for buffering messages.
        public static let buffering = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_BUFFERING.rawValue))

        /// Filter for duration changed messages.
        public static let durationChanged = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_DURATION_CHANGED.rawValue))

        /// Filter for latency messages.
        public static let latency = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_LATENCY.rawValue))

        /// Filter for tag messages.
        public static let tag = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_TAG.rawValue))

        /// Filter for QoS messages.
        public static let qos = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_QOS.rawValue))

        /// Filter for stream start messages.
        public static let streamStart = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_STREAM_START.rawValue))

        /// Filter for clock lost messages.
        public static let clockLost = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_CLOCK_LOST.rawValue))

        /// Filter for new clock messages.
        public static let newClock = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_NEW_CLOCK.rawValue))

        /// Filter for progress messages.
        public static let progress = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_PROGRESS.rawValue))

        /// Filter for info messages.
        public static let info = Filter(rawValue: UInt32(bitPattern: GST_MESSAGE_INFO.rawValue))

        /// All message types.
        public static let all: Filter = [
            .error, .warning, .info, .eos, .stateChanged, .element,
            .buffering, .durationChanged, .latency, .tag, .qos,
            .streamStart, .clockLost, .newClock, .progress
        ]

        internal var gstMessageType: GstMessageType {
            GstMessageType(rawValue: Int32(bitPattern: rawValue))
        }
    }

    /// The underlying GstBus pointer.
    internal let _bus: UnsafeMutablePointer<GstBus>

    internal init(bus: UnsafeMutablePointer<GstBus>) {
        self._bus = bus
    }

    deinit {
        swift_gst_object_unref(_bus)
    }

    /// An async stream of messages from the bus.
    ///
    /// Messages are polled from the bus without requiring a GLib main loop.
    /// The stream ends when EOS is received or the task is cancelled.
    ///
    /// - Parameter filter: Message types to receive. Defaults to error, eos, and stateChanged.
    /// - Returns: An `AsyncStream` of ``BusMessage`` values.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Basic usage - wait for completion or error
    /// for await message in pipeline.bus.messages() {
    ///     switch message {
    ///     case .eos:
    ///         print("Pipeline completed")
    ///         break
    ///     case .error(let msg, _):
    ///         print("Error: \(msg)")
    ///         break
    ///     default:
    ///         continue
    ///     }
    /// }
    /// ```
    ///
    /// ## Concurrent Processing
    ///
    /// ```swift
    /// // Monitor bus while processing frames
    /// async let busMonitor: () = {
    ///     for await message in pipeline.bus.messages(filter: [.error]) {
    ///         if case .error(let msg, _) = message {
    ///             print("Pipeline error: \(msg)")
    ///         }
    ///     }
    /// }()
    ///
    /// // Process frames concurrently
    /// for await frame in sink.frames() {
    ///     processFrame(frame)
    /// }
    ///
    /// await busMonitor
    /// ```
    public func messages(filter: Filter = [.error, .eos, .stateChanged]) -> AsyncStream<BusMessage> {
        AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                while !Task.isCancelled {
                    // Poll with 100ms timeout
                    if let msg = swift_gst_bus_timed_pop_filtered(
                        self._bus,
                        100_000_000, // 100ms in nanoseconds
                        filter.gstMessageType
                    ) {
                        if let busMessage = self.parseMessage(msg) {
                            continuation.yield(busMessage)

                            // Stop on EOS
                            if case .eos = busMessage {
                                swift_gst_message_unref(msg)
                                break
                            }
                        }
                        swift_gst_message_unref(msg)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Parse a GstMessage into a BusMessage.
    private func parseMessage(_ msg: UnsafeMutablePointer<GstMessage>) -> BusMessage? {
        let messageType = swift_gst_message_type(msg)

        switch messageType {
        case GST_MESSAGE_EOS:
            return .eos

        case GST_MESSAGE_ERROR:
            var errorString: UnsafeMutablePointer<CChar>?
            var debugString: UnsafeMutablePointer<CChar>?
            swift_gst_message_parse_error(msg, &errorString, &debugString)

            let message = GLibString.takeOwnership(errorString) ?? "Unknown error"
            let debug = GLibString.takeOwnership(debugString)

            return .error(message: message, debug: debug)

        case GST_MESSAGE_WARNING:
            var warningString: UnsafeMutablePointer<CChar>?
            var debugString: UnsafeMutablePointer<CChar>?
            swift_gst_message_parse_warning(msg, &warningString, &debugString)

            let message = GLibString.takeOwnership(warningString) ?? "Unknown warning"
            let debug = GLibString.takeOwnership(debugString)

            return .warning(message: message, debug: debug)

        case GST_MESSAGE_STATE_CHANGED:
            var oldState: GstState = GST_STATE_NULL
            var newState: GstState = GST_STATE_NULL
            var pendingState: GstState = GST_STATE_NULL
            swift_gst_message_parse_state_changed(msg, &oldState, &newState, &pendingState)
            return .stateChanged(
                old: Pipeline.State(gstState: oldState),
                new: Pipeline.State(gstState: newState)
            )

        case GST_MESSAGE_ELEMENT:
            let sourceName = GLibString.takeOwnership(swift_gst_message_src(msg).flatMap { gst_object_get_name($0) }) ?? "element"
            return .element(name: sourceName, fields: [:])

        case GST_MESSAGE_BUFFERING:
            var percent: gint = 0
            gst_message_parse_buffering(msg, &percent)
            return .buffering(percent: Int(percent))

        case GST_MESSAGE_DURATION_CHANGED:
            return .durationChanged

        case GST_MESSAGE_LATENCY:
            return .latency

        case GST_MESSAGE_TAG:
            var tagList: UnsafeMutablePointer<GstTagList>?
            gst_message_parse_tag(msg, &tagList)
            let tagString: String
            if let tags = tagList {
                tagString = GLibString.takeOwnership(gst_tag_list_to_string(tags)) ?? ""
                gst_tag_list_unref(tags)
            } else {
                tagString = ""
            }
            return .tag(tagString)

        case GST_MESSAGE_QOS:
            var live: gboolean = 0
            var runningTime: guint64 = 0
            var streamTime: guint64 = 0
            var timestamp: guint64 = 0
            var duration: guint64 = 0
            gst_message_parse_qos(msg, &live, &runningTime, &streamTime, &timestamp, &duration)
            return .qos(live: live != 0, runningTime: UInt64(runningTime), streamTime: UInt64(streamTime))

        case GST_MESSAGE_STREAM_START:
            return .streamStart

        case GST_MESSAGE_CLOCK_LOST:
            return .clockLost

        case GST_MESSAGE_NEW_CLOCK:
            return .newClock

        case GST_MESSAGE_PROGRESS:
            var progressType: GstProgressType = GST_PROGRESS_TYPE_START
            var code: UnsafeMutablePointer<gchar>?
            var text: UnsafeMutablePointer<gchar>?
            gst_message_parse_progress(msg, &progressType, &code, &text)
            let codeStr = GLibString.takeOwnership(code) ?? ""
            let textStr = GLibString.takeOwnership(text) ?? ""
            let type = BusMessage.ProgressType(rawValue: Int32(bitPattern: progressType.rawValue)) ?? .unknown
            return .progress(type: type, code: codeStr, text: textStr)

        case GST_MESSAGE_INFO:
            var infoString: UnsafeMutablePointer<CChar>?
            var debugString: UnsafeMutablePointer<CChar>?
            swift_gst_message_parse_info(msg, &infoString, &debugString)
            let message = GLibString.takeOwnership(infoString) ?? "Unknown info"
            let debug = GLibString.takeOwnership(debugString)
            return .info(message: message, debug: debug)

        default:
            return nil
        }
    }

    /// Pop a message from the bus (non-blocking). Low-level API.
    internal func pop() -> UnsafeMutablePointer<GstMessage>? {
        swift_gst_bus_pop(_bus)
    }

    /// Pop a message from the bus with timeout. Low-level API.
    internal func pop(timeout: UInt64) -> UnsafeMutablePointer<GstMessage>? {
        swift_gst_bus_timed_pop(_bus, GstClockTime(timeout))
    }

    /// Pop a message from the bus filtered by type. Low-level API.
    internal func pop(timeout: UInt64, filter: Filter) -> UnsafeMutablePointer<GstMessage>? {
        swift_gst_bus_timed_pop_filtered(_bus, GstClockTime(timeout), filter.gstMessageType)
    }

    // MARK: - Convenience Methods

    /// Wait for the end-of-stream message.
    ///
    /// This method blocks until an EOS message is received, making it useful
    /// for simple playback scenarios where you want to wait for completion.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("filesrc location=video.mp4 ! decodebin ! autovideosink")
    /// try pipeline.play()
    ///
    /// // Wait for playback to complete
    /// await pipeline.bus.waitForEOS()
    /// pipeline.stop()
    /// ```
    public func waitForEOS() async {
        for await message in messages(filter: .eos) {
            if case .eos = message {
                return
            }
        }
    }

    /// An async stream of only error messages.
    ///
    /// This is a convenience method that filters for error messages only,
    /// providing a simpler API for error monitoring.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Monitor for errors in a separate task
    /// Task {
    ///     for await (message, debug) in pipeline.bus.errors() {
    ///         print("Error: \(message)")
    ///         if let debug {
    ///             print("Debug: \(debug)")
    ///         }
    ///     }
    /// }
    /// ```
    public func errors() -> AsyncStream<(message: String, debug: String?)> {
        AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                for await msg in self.messages(filter: .error) {
                    if case .error(let message, let debug) = msg {
                        continuation.yield((message, debug))
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// An async stream of only warning messages.
    ///
    /// This is a convenience method that filters for warning messages only.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await (message, debug) in pipeline.bus.warnings() {
    ///     print("Warning: \(message)")
    /// }
    /// ```
    public func warnings() -> AsyncStream<(message: String, debug: String?)> {
        AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                for await msg in self.messages(filter: .warning) {
                    if case .warning(let message, let debug) = msg {
                        continuation.yield((message, debug))
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// An async stream of state change messages.
    ///
    /// This is a convenience method for monitoring state transitions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await (old, new) in pipeline.bus.stateChanges() {
    ///     print("State changed: \(old) → \(new)")
    ///     if new == .playing {
    ///         print("Pipeline is now playing")
    ///     }
    /// }
    /// ```
    public func stateChanges() -> AsyncStream<(old: Pipeline.State, new: Pipeline.State)> {
        AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                for await msg in self.messages(filter: .stateChanged) {
                    if case .stateChanged(let old, let new) = msg {
                        continuation.yield((old, new))
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
