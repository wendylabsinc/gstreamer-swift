/// A GStreamer timestamp representing a point in time or duration.
///
/// GStreamer uses nanoseconds internally for all time values. This type provides
/// a type-safe wrapper with convenient conversions to Swift's `Duration` and
/// human-readable formats.
///
/// ## Overview
///
/// Use `Timestamp` to work with GStreamer time values in a type-safe manner.
/// All GStreamer timestamps (PTS, DTS, duration, position) can be wrapped
/// in this type for easier manipulation.
///
/// ## Example
///
/// ```swift
/// // Create from nanoseconds
/// let timestamp = Timestamp(nanoseconds: frame.pts ?? 0)
/// print("Frame at \(timestamp.seconds)s")
///
/// // Create from Duration
/// let seekPosition = Timestamp(duration: .seconds(30))
/// try pipeline.seek(to: seekPosition.nanoseconds)
///
/// // Format for display
/// print(timestamp.formatted)  // "00:30.000"
/// ```
public struct Timestamp: Sendable, Hashable, Comparable {
    /// The raw nanosecond value.
    public let nanoseconds: UInt64

    /// Create a timestamp from nanoseconds.
    ///
    /// - Parameter nanoseconds: The time value in nanoseconds.
    public init(nanoseconds: UInt64) {
        self.nanoseconds = nanoseconds
    }

    /// Create a timestamp from a Swift Duration.
    ///
    /// - Parameter duration: A Swift Duration value.
    public init(duration: Duration) {
        let (seconds, attoseconds) = duration.components
        // Convert seconds + attoseconds to nanoseconds
        // 1 attosecond = 10^-18 seconds, 1 nanosecond = 10^-9 seconds
        // So attoseconds / 10^9 = nanoseconds from the attosecond part
        let nsFromSeconds = UInt64(seconds) * 1_000_000_000
        let nsFromAttoseconds = UInt64(attoseconds / 1_000_000_000)
        self.nanoseconds = nsFromSeconds + nsFromAttoseconds
    }

    /// Create a timestamp from seconds.
    ///
    /// - Parameter seconds: The time value in seconds.
    public init(seconds: Double) {
        self.nanoseconds = UInt64(seconds * 1_000_000_000.0)
    }

    /// Create a timestamp from milliseconds.
    ///
    /// - Parameter milliseconds: The time value in milliseconds.
    public init(milliseconds: Double) {
        self.nanoseconds = UInt64(milliseconds * 1_000_000.0)
    }

    // MARK: - Conversions

    /// The timestamp as a Swift Duration.
    public var duration: Duration {
        .nanoseconds(Int64(nanoseconds))
    }

    /// The timestamp in seconds.
    public var seconds: Double {
        Double(nanoseconds) / 1_000_000_000.0
    }

    /// The timestamp in milliseconds.
    public var milliseconds: Double {
        Double(nanoseconds) / 1_000_000.0
    }

    /// The timestamp in microseconds.
    public var microseconds: Double {
        Double(nanoseconds) / 1_000.0
    }

    // MARK: - Formatting

    /// A human-readable time string (MM:SS.mmm or HH:MM:SS.mmm).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ts = Timestamp(seconds: 3661.5)
    /// print(ts.formatted)  // "01:01:01.500"
    /// ```
    public var formatted: String {
        let totalSeconds = seconds
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let secs = Int(totalSeconds) % 60
        let ms = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 1000)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, ms)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, secs, ms)
        }
    }

    // MARK: - Comparable

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

    // MARK: - Arithmetic

    /// Add two timestamps.
    public static func + (lhs: Timestamp, rhs: Timestamp) -> Timestamp {
        Timestamp(nanoseconds: lhs.nanoseconds + rhs.nanoseconds)
    }

    /// Subtract two timestamps.
    public static func - (lhs: Timestamp, rhs: Timestamp) -> Timestamp {
        Timestamp(nanoseconds: lhs.nanoseconds - rhs.nanoseconds)
    }

    /// Add a Duration to a timestamp.
    public static func + (lhs: Timestamp, rhs: Duration) -> Timestamp {
        lhs + Timestamp(duration: rhs)
    }

    /// Subtract a Duration from a timestamp.
    public static func - (lhs: Timestamp, rhs: Duration) -> Timestamp {
        lhs - Timestamp(duration: rhs)
    }

    // MARK: - Constants

    /// Zero timestamp.
    public static let zero = Timestamp(nanoseconds: 0)

    /// One second.
    public static let oneSecond = Timestamp(nanoseconds: 1_000_000_000)

    /// One millisecond.
    public static let oneMillisecond = Timestamp(nanoseconds: 1_000_000)

    /// Invalid/undefined timestamp (equivalent to GST_CLOCK_TIME_NONE).
    public static let invalid = Timestamp(nanoseconds: UInt64.max)

    /// Check if this timestamp is valid.
    public var isValid: Bool {
        nanoseconds != UInt64.max
    }
}

// MARK: - CustomStringConvertible

extension Timestamp: CustomStringConvertible {
    public var description: String {
        if isValid {
            return formatted
        } else {
            return "invalid"
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Timestamp: ExpressibleByIntegerLiteral {
    /// Create a timestamp from an integer literal (interpreted as nanoseconds).
    public init(integerLiteral value: UInt64) {
        self.nanoseconds = value
    }
}

// MARK: - Convenience Extensions for Optional UInt64

extension Optional where Wrapped == UInt64 {
    /// Convert an optional nanosecond value to an optional Timestamp.
    public var asTimestamp: Timestamp? {
        self.map { Timestamp(nanoseconds: $0) }
    }
}
