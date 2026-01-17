import CGStreamer
import CGStreamerShim

// MARK: - Query Results

/// Result of a latency query.
public struct LatencyInfo: Sendable {
    /// Whether the pipeline is live.
    public let isLive: Bool
    /// Minimum latency in nanoseconds.
    public let minLatency: UInt64
    /// Maximum latency in nanoseconds.
    public let maxLatency: UInt64
}

/// Result of a seeking query.
public struct SeekingInfo: Sendable {
    /// Whether seeking is supported.
    public let isSeekable: Bool
    /// Start of seekable range in nanoseconds.
    public let start: UInt64
    /// End of seekable range in nanoseconds.
    public let end: UInt64
}

/// Result of a buffering query.
public struct BufferingInfo: Sendable {
    /// Buffering percentage (0-100).
    public let percent: Int
    /// Buffering mode.
    public let mode: BufferingMode
    /// Average input rate in bytes per second.
    public let averageIn: Int
    /// Average output rate in bytes per second.
    public let averageOut: Int

    /// Buffering mode types.
    public enum BufferingMode: Int32, Sendable {
        case stream = 0
        case download = 1
        case timeshift = 2
        case live = 3
    }
}

// MARK: - Pipeline Query Extensions

extension Pipeline {
    /// Query latency information from the pipeline.
    ///
    /// - Returns: Latency information, or `nil` if the query failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let latency = pipeline.queryLatency() {
    ///     print("Live: \(latency.isLive)")
    ///     print("Min latency: \(latency.minLatency / 1_000_000)ms")
    ///     print("Max latency: \(latency.maxLatency / 1_000_000)ms")
    /// }
    /// ```
    public func queryLatency() -> LatencyInfo? {
        let query = gst_query_new_latency()
        defer { gst_query_unref(query) }

        guard gst_element_query(_element, query) != 0 else {
            return nil
        }

        var live: gboolean = 0
        var minLatency: GstClockTime = 0
        var maxLatency: GstClockTime = 0
        gst_query_parse_latency(query, &live, &minLatency, &maxLatency)

        return LatencyInfo(
            isLive: live != 0,
            minLatency: minLatency,
            maxLatency: maxLatency
        )
    }

    /// Query whether seeking is supported.
    ///
    /// - Returns: Seeking information, or `nil` if the query failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let seeking = pipeline.querySeekingInfo() {
    ///     if seeking.isSeekable {
    ///         print("Can seek from \(seeking.start) to \(seeking.end)")
    ///     } else {
    ///         print("Stream is not seekable")
    ///     }
    /// }
    /// ```
    public func querySeekingInfo() -> SeekingInfo? {
        let query = gst_query_new_seeking(GST_FORMAT_TIME)
        defer { gst_query_unref(query) }

        guard gst_element_query(_element, query) != 0 else {
            return nil
        }

        var format: GstFormat = GST_FORMAT_TIME
        var seekable: gboolean = 0
        var start: gint64 = 0
        var end: gint64 = 0
        gst_query_parse_seeking(query, &format, &seekable, &start, &end)

        return SeekingInfo(
            isSeekable: seekable != 0,
            start: UInt64(max(0, start)),
            end: UInt64(max(0, end))
        )
    }

    /// Query buffering status.
    ///
    /// - Returns: Buffering information, or `nil` if the query failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let buffering = pipeline.queryBuffering() {
    ///     print("Buffering: \(buffering.percent)%")
    /// }
    /// ```
    public func queryBuffering() -> BufferingInfo? {
        let query = gst_query_new_buffering(GST_FORMAT_PERCENT)
        defer { gst_query_unref(query) }

        guard gst_element_query(_element, query) != 0 else {
            return nil
        }

        var percent: gint = 0
        var busy: gboolean = 0
        gst_query_parse_buffering_percent(query, &busy, &percent)

        var mode: GstBufferingMode = GST_BUFFERING_STREAM
        var avgIn: gint = 0
        var avgOut: gint = 0
        var left: gint64 = 0
        gst_query_parse_buffering_stats(query, &mode, &avgIn, &avgOut, &left)

        return BufferingInfo(
            percent: Int(percent),
            mode: BufferingInfo.BufferingMode(rawValue: Int32(bitPattern: mode.rawValue)) ?? .stream,
            averageIn: Int(avgIn),
            averageOut: Int(avgOut)
        )
    }

    /// Convert a value from one format to another.
    ///
    /// For example, convert a time position to bytes, or vice versa.
    ///
    /// - Parameters:
    ///   - value: The source value.
    ///   - from: The source format.
    ///   - to: The destination format.
    /// - Returns: The converted value, or `nil` if conversion failed.
    public func convert(_ value: Int64, from: Format, to: Format) -> Int64? {
        var result: gint64 = 0
        guard gst_element_query_convert(_element, from.gstFormat, gint64(value), to.gstFormat, &result) != 0 else {
            return nil
        }
        return Int64(result)
    }

    /// Format types for conversion queries.
    public enum Format: Sendable {
        case time
        case bytes
        case buffers
        case percent

        var gstFormat: GstFormat {
            switch self {
            case .time: return GST_FORMAT_TIME
            case .bytes: return GST_FORMAT_BYTES
            case .buffers: return GST_FORMAT_BUFFERS
            case .percent: return GST_FORMAT_PERCENT
            }
        }
    }
}
