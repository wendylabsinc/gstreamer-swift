import CGStreamer
import CGStreamerShim

/// A GStreamer bus message.
public final class Message: @unchecked Sendable {
    /// The underlying GstMessage pointer.
    internal let message: UnsafeMutablePointer<GstMessage>

    internal init(message: UnsafeMutablePointer<GstMessage>) {
        self.message = message
    }

    deinit {
        swift_gst_message_unref(message)
    }

    /// The message type.
    public var type: MessageType {
        let gstType = swift_gst_message_type(message)
        return MessageType(rawValue: UInt32(bitPattern: gstType.rawValue))
    }

    /// The message type name as a string.
    public var typeName: String {
        guard let cName = swift_gst_message_type_name(message) else {
            return "unknown"
        }
        return String(cString: cName)
    }

    /// Parse an error message.
    /// - Returns: A tuple containing the error message and optional debug string.
    public func parseError() -> (message: String?, debug: String?) {
        var errorString: UnsafeMutablePointer<CChar>?
        var debugString: UnsafeMutablePointer<CChar>?

        swift_gst_message_parse_error(message, &errorString, &debugString)

        return (
            GLibString.takeOwnership(errorString),
            GLibString.takeOwnership(debugString)
        )
    }

    /// Parse a warning message.
    /// - Returns: A tuple containing the warning message and optional debug string.
    public func parseWarning() -> (message: String?, debug: String?) {
        var warningString: UnsafeMutablePointer<CChar>?
        var debugString: UnsafeMutablePointer<CChar>?

        swift_gst_message_parse_warning(message, &warningString, &debugString)

        return (
            GLibString.takeOwnership(warningString),
            GLibString.takeOwnership(debugString)
        )
    }

    /// Parse an info message.
    /// - Returns: A tuple containing the info message and optional debug string.
    public func parseInfo() -> (message: String?, debug: String?) {
        var infoString: UnsafeMutablePointer<CChar>?
        var debugString: UnsafeMutablePointer<CChar>?

        swift_gst_message_parse_info(message, &infoString, &debugString)

        return (
            GLibString.takeOwnership(infoString),
            GLibString.takeOwnership(debugString)
        )
    }
}

// MARK: - MessageType

extension Message {
    /// GStreamer message types.
    public struct MessageType: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let unknown = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_UNKNOWN.rawValue))
        public static let eos = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_EOS.rawValue))
        public static let error = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_ERROR.rawValue))
        public static let warning = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_WARNING.rawValue))
        public static let info = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_INFO.rawValue))
        public static let tag = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_TAG.rawValue))
        public static let buffering = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_BUFFERING.rawValue))
        public static let stateChanged = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STATE_CHANGED.rawValue))
        public static let stateDirty = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STATE_DIRTY.rawValue))
        public static let stepDone = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STEP_DONE.rawValue))
        public static let clockProvide = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_CLOCK_PROVIDE.rawValue))
        public static let clockLost = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_CLOCK_LOST.rawValue))
        public static let newClock = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_NEW_CLOCK.rawValue))
        public static let structureChange = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STRUCTURE_CHANGE.rawValue))
        public static let streamStatus = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STREAM_STATUS.rawValue))
        public static let application = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_APPLICATION.rawValue))
        public static let element = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_ELEMENT.rawValue))
        public static let segmentStart = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_SEGMENT_START.rawValue))
        public static let segmentDone = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_SEGMENT_DONE.rawValue))
        public static let durationChanged = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_DURATION_CHANGED.rawValue))
        public static let latency = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_LATENCY.rawValue))
        public static let asyncStart = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_ASYNC_START.rawValue))
        public static let asyncDone = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_ASYNC_DONE.rawValue))
        public static let requestState = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_REQUEST_STATE.rawValue))
        public static let stepStart = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STEP_START.rawValue))
        public static let qos = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_QOS.rawValue))
        public static let progress = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_PROGRESS.rawValue))
        public static let toc = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_TOC.rawValue))
        public static let resetTime = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_RESET_TIME.rawValue))
        public static let streamStart = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_STREAM_START.rawValue))
        public static let needContext = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_NEED_CONTEXT.rawValue))
        public static let haveContext = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_HAVE_CONTEXT.rawValue))

        public static let any = MessageType(rawValue: UInt32(bitPattern: GST_MESSAGE_ANY.rawValue))
    }
}
