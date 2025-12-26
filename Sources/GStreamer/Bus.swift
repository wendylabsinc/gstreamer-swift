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

            let message = errorString.map { String(cString: $0) } ?? "Unknown error"
            let debug = debugString.map { String(cString: $0) }

            errorString.map { g_free($0) }
            debugString.map { g_free($0) }

            return .error(message: message, debug: debug)

        case GST_MESSAGE_WARNING:
            var warningString: UnsafeMutablePointer<CChar>?
            var debugString: UnsafeMutablePointer<CChar>?
            swift_gst_message_parse_warning(msg, &warningString, &debugString)

            let message = warningString.map { String(cString: $0) } ?? "Unknown warning"
            let debug = debugString.map { String(cString: $0) }

            warningString.map { g_free($0) }
            debugString.map { g_free($0) }

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
            // Simplified element message
            return .element(name: "element", fields: [:])

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
}
