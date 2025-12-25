import CGStreamer
import CGStreamerShim

/// A GStreamer element wrapper for dynamic property access.
///
/// Element provides a Swift interface to GStreamer elements within a pipeline.
/// Use it to get and set element properties at runtime.
///
/// ## Overview
///
/// Elements are the building blocks of GStreamer pipelines. Each element performs
/// a specific function: sources produce data, filters transform it, and sinks
/// consume it. This wrapper allows you to access elements by name and modify
/// their properties.
///
/// ## Topics
///
/// ### Element Properties
///
/// - ``name``
///
/// ### Setting Properties
///
/// - ``set(_:_:)-7r6xd``
/// - ``set(_:_:)-6y4xr``
/// - ``set(_:_:)-9mvg4``
///
/// ## Example
///
/// ```swift
/// let pipeline = try Pipeline("videotestsrc name=src pattern=0 ! autovideosink")
///
/// // Get element by name
/// if let src = pipeline.element(named: "src") {
///     print("Element name: \(src.name)")
///
///     // Change the test pattern at runtime
///     src.set("pattern", 1)  // Switch to snow pattern
/// }
/// ```
///
/// ## Common Element Properties
///
/// ### videotestsrc
///
/// ```swift
/// let src = pipeline.element(named: "src")!
/// src.set("pattern", 0)     // SMPTE color bars
/// src.set("pattern", 1)     // Snow (random noise)
/// src.set("pattern", 2)     // Black
/// src.set("is-live", true)  // Simulate live source
/// ```
///
/// ### v4l2src (Linux webcam)
///
/// ```swift
/// let webcam = pipeline.element(named: "webcam")!
/// webcam.set("device", "/dev/video0")
/// webcam.set("brightness", 128)
/// webcam.set("contrast", 64)
/// ```
///
/// ### filesrc
///
/// ```swift
/// let file = pipeline.element(named: "file")!
/// file.set("location", "/path/to/video.mp4")
/// ```
public final class Element: @unchecked Sendable {
    /// The underlying GstElement pointer.
    internal let element: UnsafeMutablePointer<GstElement>

    /// Whether this element owns the reference (should unref on deinit).
    private let ownsReference: Bool

    internal init(element: UnsafeMutablePointer<GstElement>, ownsReference: Bool = true) {
        self.element = element
        self.ownsReference = ownsReference
    }

    deinit {
        if ownsReference {
            swift_gst_object_unref(element)
        }
    }

    /// The element's name.
    ///
    /// This is the name assigned in the pipeline description using `name=identifier`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("videotestsrc name=mysource ! fakesink")
    /// let element = pipeline.element(named: "mysource")!
    /// print(element.name) // "mysource"
    /// ```
    public var name: String {
        guard let cName = swift_gst_element_get_name(element) else {
            return ""
        }
        defer { g_free(cName) }
        return String(cString: cName)
    }

    /// Set a boolean property on this element.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The boolean value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Make a source behave as a live source
    /// source.set("is-live", true)
    ///
    /// // Enable sync on sink
    /// sink.set("sync", true)
    /// ```
    public func set(_ key: String, _ value: Bool) {
        swift_gst_element_set_bool(element, key, value ? 1 : 0)
    }

    /// Set an integer property on this element.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The integer value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set test pattern (0=SMPTE, 1=snow, 2=black, etc.)
    /// source.set("pattern", 1)
    ///
    /// // Set number of buffers to produce
    /// source.set("num-buffers", 100)
    ///
    /// // Set bitrate for encoder
    /// encoder.set("bitrate", 5000000)
    /// ```
    public func set(_ key: String, _ value: Int) {
        swift_gst_element_set_int(element, key, Int32(value))
    }

    /// Set a string property on this element.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The string value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set file location
    /// filesrc.set("location", "/path/to/video.mp4")
    ///
    /// // Set device path for v4l2
    /// webcam.set("device", "/dev/video0")
    ///
    /// // Set URI for network sources
    /// urisrc.set("uri", "rtsp://camera.local/stream")
    /// ```
    public func set(_ key: String, _ value: String) {
        swift_gst_element_set_string(element, key, value)
    }
}
