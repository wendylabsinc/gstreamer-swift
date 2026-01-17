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
/// ### Creating Elements
///
/// - ``make(factory:name:)``
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
/// ### Pads and Linking
///
/// - ``staticPad(_:)``
/// - ``requestPad(_:)``
/// - ``releasePad(_:)``
/// - ``link(to:)``
/// - ``syncStateWithParent()``
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
///
/// ## Thread Safety
///
/// Element is marked as `@unchecked Sendable` because it wraps a GStreamer C pointer.
/// GStreamer's element property system is generally thread-safe for reads and writes,
/// but concurrent modifications to the same property may have undefined behavior.
///
/// - Note: For thread-safe property access in highly concurrent code, consider using
///   external synchronization or performing all property modifications from a single
///   isolation domain.
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
        GLibString.takeOwnership(swift_gst_element_get_name(element)) ?? ""
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

    /// Set a double property on this element.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The double value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set volume level (0.0 - 1.0+)
    /// volume.set("volume", 0.8)
    ///
    /// // Set playback rate
    /// element.set("rate", 1.5)
    /// ```
    public func set(_ key: String, _ value: Double) {
        swift_gst_element_set_double(element, key, value)
    }

    // MARK: - Property Getters

    /// Get a boolean property from this element.
    ///
    /// - Parameter key: The property name.
    /// - Returns: The property value, or `false` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let isLive = source.getBool("is-live")
    /// let sync = sink.getBool("sync")
    /// ```
    public func getBool(_ key: String) -> Bool {
        swift_gst_element_get_bool(element, key) != 0
    }

    /// Get an integer property from this element.
    ///
    /// - Parameter key: The property name.
    /// - Returns: The property value, or `0` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pattern = source.getInt("pattern")
    /// let numBuffers = source.getInt("num-buffers")
    /// let bitrate = encoder.getInt("bitrate")
    /// ```
    public func getInt(_ key: String) -> Int {
        Int(swift_gst_element_get_int(element, key))
    }

    /// Get a string property from this element.
    ///
    /// - Parameter key: The property name.
    /// - Returns: The property value, or `nil` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let location = filesrc.getString("location") {
    ///     print("File: \(location)")
    /// }
    /// if let device = webcam.getString("device") {
    ///     print("Device: \(device)")
    /// }
    /// ```
    public func getString(_ key: String) -> String? {
        GLibString.takeOwnership(swift_gst_element_get_string(element, key))
    }

    /// Get a double property from this element.
    ///
    /// - Parameter key: The property name.
    /// - Returns: The property value, or `0.0` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let volume = volumeElement.getDouble("volume")
    /// let rate = element.getDouble("rate")
    /// ```
    public func getDouble(_ key: String) -> Double {
        swift_gst_element_get_double(element, key)
    }

    // MARK: - Factory Creation

    /// Create an element from a factory name.
    ///
    /// This allows you to create elements programmatically for dynamic pipelines.
    ///
    /// - Parameters:
    ///   - factory: The element factory name (e.g., "queue", "tee", "videoscale").
    ///   - name: Optional name for the element.
    /// - Returns: The created element.
    /// - Throws: ``GStreamerError/elementNotFound(_:)`` if the factory doesn't exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a queue element
    /// let queue = try Element.make(factory: "queue", name: "myqueue")
    ///
    /// // Create a tee for splitting streams
    /// let tee = try Element.make(factory: "tee", name: "splitter")
    ///
    /// // Add to pipeline
    /// pipeline.add(queue)
    /// queue.syncStateWithParent()
    /// ```
    public static func make(factory: String, name: String? = nil) throws -> Element {
        guard let el = swift_gst_element_factory_make(factory, name) else {
            throw GStreamerError.elementNotFound(factory)
        }
        return Element(element: el, ownsReference: true)
    }

    // MARK: - Pads and Linking

    /// Get a static pad from the element.
    ///
    /// Static pads are always present on an element (e.g., "sink", "src").
    ///
    /// - Parameter name: The pad name.
    /// - Returns: The pad, or `nil` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sinkPad = element.staticPad("sink")
    /// let srcPad = element.staticPad("src")
    /// ```
    public func staticPad(_ name: String) -> Pad? {
        guard let pad = swift_gst_element_get_static_pad(element, name) else {
            return nil
        }
        return Pad(pad: pad)
    }

    /// Request a pad from the element.
    ///
    /// Request pads are created on demand (e.g., "src_%u" on tee).
    ///
    /// - Parameter name: The pad template name.
    /// - Returns: The requested pad, or `nil` if failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Request a new source pad from a tee
    /// if let pad = tee.requestPad("src_%u") {
    ///     // Link to downstream element
    ///     pad.link(to: queue.staticPad("sink")!)
    /// }
    /// ```
    public func requestPad(_ name: String) -> Pad? {
        guard let pad = swift_gst_element_request_pad_simple(element, name) else {
            return nil
        }
        return Pad(pad: pad, isRequestPad: true, element: self)
    }

    /// Release a previously requested pad.
    ///
    /// - Parameter pad: The pad to release.
    public func releasePad(_ pad: Pad) {
        swift_gst_element_release_request_pad(element, pad.pad)
    }

    /// Link this element to another element.
    ///
    /// - Parameter other: The downstream element to link to.
    /// - Returns: `true` if linking succeeded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let success = source.link(to: sink)
    /// ```
    @discardableResult
    public func link(to other: Element) -> Bool {
        swift_gst_element_link(element, other.element) != 0
    }

    /// Synchronize this element's state with its parent.
    ///
    /// Call this after adding an element to a running pipeline.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let queue = try Element.make(factory: "queue")
    /// pipeline.add(queue)
    /// queue.syncStateWithParent()
    /// ```
    @discardableResult
    public func syncStateWithParent() -> Bool {
        swift_gst_element_sync_state_with_parent(element) != 0
    }

    // MARK: - Fluent Property Setting

    /// Set a boolean property and return self for chaining.
    ///
    /// This method allows fluent-style property configuration.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The boolean value.
    /// - Returns: Self for method chaining.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let src = try Element.make(factory: "videotestsrc")
    ///     .with("is-live", true)
    ///     .with("pattern", 1)
    ///     .with("num-buffers", 100)
    /// ```
    @discardableResult
    public func with(_ key: String, _ value: Bool) -> Element {
        set(key, value)
        return self
    }

    /// Set an integer property and return self for chaining.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The integer value.
    /// - Returns: Self for method chaining.
    @discardableResult
    public func with(_ key: String, _ value: Int) -> Element {
        set(key, value)
        return self
    }

    /// Set a string property and return self for chaining.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The string value.
    /// - Returns: Self for method chaining.
    @discardableResult
    public func with(_ key: String, _ value: String) -> Element {
        set(key, value)
        return self
    }

    /// Set a double property and return self for chaining.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The double value.
    /// - Returns: Self for method chaining.
    @discardableResult
    public func with(_ key: String, _ value: Double) -> Element {
        set(key, value)
        return self
    }

    /// Set multiple properties at once.
    ///
    /// - Parameter properties: A dictionary of property names to values.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let src = try Element.make(factory: "videotestsrc")
    /// src.setProperties([
    ///     "pattern": 1,
    ///     "is-live": true,
    ///     "num-buffers": 100
    /// ])
    /// ```
    public func setProperties(_ properties: [String: Any]) {
        for (key, value) in properties {
            switch value {
            case let v as Bool:
                set(key, v)
            case let v as Int:
                set(key, v)
            case let v as String:
                set(key, v)
            case let v as Double:
                set(key, v)
            default:
                // Skip unsupported types
                break
            }
        }
    }
}
