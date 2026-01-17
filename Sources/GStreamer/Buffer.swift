import CGStreamer
import CGStreamerShim

/// A GStreamer buffer for holding media data.
///
/// Buffer is a value type with copy-on-write semantics. When you copy a buffer,
/// the underlying data is shared until you mutate one of the copies.
///
/// ## Creating Buffers
///
/// ```swift
/// // Create an empty buffer
/// var buffer = try Buffer(size: 1920 * 1080 * 4)
///
/// // Create a buffer from data
/// let data: [UInt8] = ...
/// var buffer = try Buffer(data: data)
///
/// // Create a buffer with timestamps
/// var buffer = try Buffer(size: frameSize, pts: 0, duration: 33_333_333)
/// ```
///
/// ## Copy-on-Write Behavior
///
/// ```swift
/// var buffer1 = try Buffer(size: 1000)
/// var buffer2 = buffer1  // Shares underlying storage
///
/// // Mutating buffer2 triggers a copy
/// buffer2.pts = 100  // buffer1 is unaffected
/// ```
///
/// ## Writing to Buffers
///
/// ```swift
/// var buffer = try Buffer(size: 1000)
/// try buffer.withUnsafeMutableBytes { ptr in
///     // Write directly to the buffer memory
///     for i in 0..<ptr.count {
///         ptr[i] = UInt8(i & 0xFF)
///     }
/// }
/// ```
///
/// ## Reading from Buffers
///
/// ```swift
/// let firstByte = buffer.bytes[0]
/// let byteCount = buffer.bytes.byteCount
/// ```
public struct Buffer: @unchecked Sendable {
    /// Internal storage class for copy-on-write semantics.
    private final class Storage: @unchecked Sendable {
        let buffer: UnsafeMutablePointer<GstBuffer>
        let ownsReference: Bool

        init(buffer: UnsafeMutablePointer<GstBuffer>, ownsReference: Bool) {
            self.buffer = buffer
            self.ownsReference = ownsReference
        }

        deinit {
            if ownsReference {
                swift_gst_buffer_unref(buffer)
            }
        }

        /// Create a copy of this storage.
        func copy() -> Storage? {
            guard let copied = gst_buffer_copy(buffer) else {
                return nil
            }
            return Storage(buffer: copied, ownsReference: true)
        }
    }

    private var storage: Storage

    /// Ensure unique ownership of storage before mutation.
    /// Returns true if we have unique access, false if copy failed.
    private mutating func ensureUnique() -> Bool {
        if !isKnownUniquelyReferenced(&storage) {
            guard let newStorage = storage.copy() else {
                return false
            }
            storage = newStorage
        }
        return true
    }

    /// Create a new buffer with the specified size.
    ///
    /// - Parameter size: The size of the buffer in bytes.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if allocation fails.
    public init(size: Int) throws {
        guard let buffer = swift_gst_buffer_new_allocate(gsize(size)) else {
            throw GStreamerError.bufferMapFailed
        }
        self.storage = Storage(buffer: buffer, ownsReference: true)
    }

    /// Create a new buffer with the specified size and timestamps.
    ///
    /// - Parameters:
    ///   - size: The size of the buffer in bytes.
    ///   - pts: Presentation timestamp in nanoseconds.
    ///   - dts: Decode timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/bufferMapFailed`` if allocation fails.
    public init(size: Int, pts: UInt64, dts: UInt64? = nil, duration: UInt64? = nil) throws {
        guard let buffer = swift_gst_buffer_new_allocate(gsize(size)) else {
            throw GStreamerError.bufferMapFailed
        }
        self.storage = Storage(buffer: buffer, ownsReference: true)

        swift_gst_buffer_set_pts(buffer, GstClockTime(pts))
        if let dts = dts {
            swift_gst_buffer_set_dts(buffer, GstClockTime(dts))
        }
        if let duration = duration {
            swift_gst_buffer_set_duration(buffer, GstClockTime(duration))
        }
    }

    /// Create a buffer from existing data.
    ///
    /// The data is copied into the buffer.
    ///
    /// - Parameters:
    ///   - data: The data to copy into the buffer.
    ///   - pts: Presentation timestamp in nanoseconds (optional).
    ///   - duration: Duration in nanoseconds (optional).
    /// - Throws: ``GStreamerError/bufferMapFailed`` if allocation fails.
    public init(data: [UInt8], pts: UInt64? = nil, duration: UInt64? = nil) throws {
        let gstPts = pts.map { GstClockTime($0) } ?? swift_gst_clock_time_none()
        let gstDuration = duration.map { GstClockTime($0) } ?? swift_gst_clock_time_none()

        guard let buffer = data.withUnsafeBytes({ bytes in
            swift_gst_buffer_new_wrapped_full(bytes.baseAddress, gsize(data.count), gstPts, gstDuration)
        }) else {
            throw GStreamerError.bufferMapFailed
        }
        self.storage = Storage(buffer: buffer, ownsReference: true)
    }

    /// Create a Buffer wrapper around an existing GstBuffer.
    ///
    /// - Parameters:
    ///   - buffer: The GstBuffer to wrap.
    ///   - ownsReference: Whether to take ownership of the reference.
    internal init(buffer: UnsafeMutablePointer<GstBuffer>, ownsReference: Bool) {
        self.storage = Storage(buffer: buffer, ownsReference: ownsReference)
    }

    /// The underlying GstBuffer pointer (for internal use).
    internal var buffer: UnsafeMutablePointer<GstBuffer> {
        storage.buffer
    }

    /// The size of the buffer in bytes.
    public var size: Int {
        Int(swift_gst_buffer_get_size(storage.buffer))
    }

    /// The presentation timestamp in nanoseconds, or nil if not set.
    public var pts: UInt64? {
        get {
            let value = swift_gst_buffer_get_pts(storage.buffer)
            return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
        }
        set {
            guard ensureUnique() else { return }
            if let newValue = newValue {
                swift_gst_buffer_set_pts(storage.buffer, GstClockTime(newValue))
            } else {
                swift_gst_buffer_set_pts(storage.buffer, swift_gst_clock_time_none())
            }
        }
    }

    /// The decode timestamp in nanoseconds, or nil if not set.
    public var dts: UInt64? {
        get {
            let value = swift_gst_buffer_get_dts(storage.buffer)
            return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
        }
        set {
            guard ensureUnique() else { return }
            if let newValue = newValue {
                swift_gst_buffer_set_dts(storage.buffer, GstClockTime(newValue))
            } else {
                swift_gst_buffer_set_dts(storage.buffer, swift_gst_clock_time_none())
            }
        }
    }

    /// The duration in nanoseconds, or nil if not set.
    public var duration: UInt64? {
        get {
            let value = swift_gst_buffer_get_duration(storage.buffer)
            return swift_gst_clock_time_is_valid(value) != 0 ? UInt64(value) : nil
        }
        set {
            guard ensureUnique() else { return }
            if let newValue = newValue {
                swift_gst_buffer_set_duration(storage.buffer, GstClockTime(newValue))
            } else {
                swift_gst_buffer_set_duration(storage.buffer, swift_gst_clock_time_none())
            }
        }
    }

    // MARK: - Buffer Access

    /// The buffer's data as a read-only span.
    ///
    /// This property provides lifetime-bound access to the buffer's bytes.
    /// The span cannot escape the scope in which it's accessed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let buffer = try Buffer(data: [1, 2, 3, 4])
    /// let firstByte = buffer.bytes[0]
    /// ```
    public var bytes: RawSpan {
        _read {
            var mapInfo = GstMapInfo()
            guard swift_gst_buffer_map_read(storage.buffer, &mapInfo) != 0 else {
                fatalError("Failed to map buffer for reading")
            }
            defer { swift_gst_buffer_unmap(storage.buffer, &mapInfo) }
            yield RawSpan(_unsafeStart: mapInfo.data, byteCount: Int(mapInfo.size))
        }
    }

    /// The buffer's data as a mutable span.
    ///
    /// This property provides lifetime-bound mutable access to the buffer's bytes.
    /// Triggers copy-on-write if the buffer is shared.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var buffer = try Buffer(size: 1920 * 1080 * 4)
    /// // Fill with red pixels (BGRA)
    /// for i in stride(from: 0, to: buffer.mutableBytes.byteCount, by: 4) {
    ///     buffer.mutableBytes[i] = 0       // Blue
    ///     buffer.mutableBytes[i + 1] = 0   // Green
    ///     buffer.mutableBytes[i + 2] = 255 // Red
    ///     buffer.mutableBytes[i + 3] = 255 // Alpha
    /// }
    /// ```
    public var mutableBytes: MutableRawSpan {
        _read {
            fatalError("Cannot read mutableBytes")
        }
        _modify {
            guard isKnownUniquelyReferenced(&storage) || storage.copy() != nil else {
                fatalError("Failed to ensure unique buffer ownership")
            }
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.copy()!
            }
            var mapInfo = GstMapInfo()
            guard swift_gst_buffer_map_write(storage.buffer, &mapInfo) != 0 else {
                fatalError("Failed to map buffer for writing")
            }
            defer { swift_gst_buffer_unmap(storage.buffer, &mapInfo) }
            var span = MutableRawSpan(_unsafeStart: mapInfo.data, byteCount: Int(mapInfo.size))
            yield &span
        }
    }

    /// Access the buffer's data for writing using unsafe pointers.
    ///
    /// This method provides direct pointer access for interoperability with C APIs
    /// or performance-critical code. Prefer ``mutableBytes`` when possible.
    ///
    /// - Parameter body: A closure that receives an UnsafeMutableRawBufferPointer.
    /// - Returns: The value returned by the closure.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if mapping fails.
    public mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        guard ensureUnique() else {
            throw GStreamerError.bufferMapFailed
        }

        var mapInfo = GstMapInfo()
        guard swift_gst_buffer_map_write(storage.buffer, &mapInfo) != 0 else {
            throw GStreamerError.bufferMapFailed
        }
        defer {
            swift_gst_buffer_unmap(storage.buffer, &mapInfo)
        }

        let ptr = UnsafeMutableRawBufferPointer(start: mapInfo.data, count: Int(mapInfo.size))
        return try body(ptr)
    }

    /// Fill the buffer with data from an array.
    ///
    /// This method ensures the buffer has unique ownership before writing
    /// (copy-on-write).
    ///
    /// - Parameters:
    ///   - data: The data to copy into the buffer.
    ///   - offset: The offset in the buffer to start writing at.
    /// - Returns: The number of bytes written.
    @discardableResult
    public mutating func fill(from data: [UInt8], offset: Int = 0) -> Int {
        guard ensureUnique() else { return 0 }
        return data.withUnsafeBytes { bytes in
            Int(swift_gst_buffer_fill(storage.buffer, gsize(offset), bytes.baseAddress, gsize(bytes.count)))
        }
    }

    /// Fill the buffer with data from a span.
    ///
    /// This method ensures the buffer has unique ownership before writing
    /// (copy-on-write).
    ///
    /// - Parameters:
    ///   - data: The span of data to copy into the buffer.
    ///   - offset: The offset in the buffer to start writing at.
    /// - Returns: The number of bytes written.
    @discardableResult
    public mutating func fill(from data: borrowing Span<UInt8>, offset: Int = 0) -> Int {
        guard ensureUnique() else { return 0 }
        return data.withUnsafeBufferPointer { bytes in
            Int(swift_gst_buffer_fill(storage.buffer, gsize(offset), bytes.baseAddress, gsize(bytes.count)))
        }
    }

    /// Fill the buffer with data from a raw span.
    ///
    /// This method ensures the buffer has unique ownership before writing
    /// (copy-on-write).
    ///
    /// - Parameters:
    ///   - data: The raw span of data to copy into the buffer.
    ///   - offset: The offset in the buffer to start writing at.
    /// - Returns: The number of bytes written.
    @discardableResult
    public mutating func fill(from data: borrowing RawSpan, offset: Int = 0) -> Int {
        guard ensureUnique() else { return 0 }
        return data.withUnsafeBytes { bytes in
            Int(swift_gst_buffer_fill(storage.buffer, gsize(offset), bytes.baseAddress, gsize(bytes.count)))
        }
    }
}
