import CGStreamer
import CGStreamerShim

/// A discovered media device (camera, microphone, etc.).
///
/// Device represents a hardware device that can be used as a source or sink
/// in a GStreamer pipeline. Use ``DeviceMonitor`` to discover available devices.
///
/// ## Topics
///
/// ### Device Properties
///
/// - ``displayName``
/// - ``deviceClass``
/// - ``caps``
///
/// ### Creating Elements
///
/// - ``createElement(name:)``
///
/// ## Example
///
/// ```swift
/// let monitor = DeviceMonitor()
/// for device in monitor.videoSources() {
///     print("Camera: \(device.displayName)")
///     if let element = device.createElement(name: "camera") {
///         // Use in pipeline
///     }
/// }
/// ```
public final class Device: @unchecked Sendable {
    internal let device: UnsafeMutablePointer<GstDevice>

    internal init(device: UnsafeMutablePointer<GstDevice>) {
        self.device = device
    }

    deinit {
        swift_gst_device_unref(device)
    }

    /// The human-readable display name of the device.
    ///
    /// ## Example
    ///
    /// ```swift
    /// print("Device: \(device.displayName)")
    /// // Output: "FaceTime HD Camera" or "USB Webcam"
    /// ```
    public var displayName: String {
        guard let name = swift_gst_device_get_display_name(device) else {
            return ""
        }
        defer { g_free(name) }
        return String(cString: name)
    }

    /// The device class (e.g., "Video/Source", "Audio/Source").
    ///
    /// ## Example
    ///
    /// ```swift
    /// if device.deviceClass.contains("Video") {
    ///     print("This is a video device")
    /// }
    /// ```
    public var deviceClass: String {
        guard let cls = swift_gst_device_get_device_class(device) else {
            return ""
        }
        return String(cString: cls)
    }

    /// The capabilities of the device.
    ///
    /// Returns a caps string describing supported formats.
    public var caps: String? {
        guard let gstCaps = swift_gst_device_get_caps(device) else {
            return nil
        }
        defer { swift_gst_caps_unref(gstCaps) }
        guard let str = swift_gst_caps_to_string(gstCaps) else {
            return nil
        }
        defer { g_free(str) }
        return String(cString: str)
    }

    /// Get a device property by name.
    ///
    /// - Parameter name: The property name (e.g., "device.path", "device.api").
    /// - Returns: The property value, or `nil` if not found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let path = device.property("device.path") {
    ///     print("Path: \(path)")  // e.g., "/dev/video0"
    /// }
    /// ```
    public func property(_ name: String) -> String? {
        guard let value = swift_gst_device_get_property_string(device, name) else {
            return nil
        }
        defer { g_free(value) }
        return String(cString: value)
    }

    /// Create a GStreamer element for this device.
    ///
    /// This creates a properly configured source element for the device.
    ///
    /// - Parameter name: Optional name for the element.
    /// - Returns: The created element, or `nil` if creation failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let source = device.createElement(name: "webcam") {
    ///     pipeline.add(source)
    ///     source.link(to: nextElement)
    /// }
    /// ```
    public func createElement(name: String? = nil) -> Element? {
        guard let el = swift_gst_device_create_element(device, name) else {
            return nil
        }
        return Element(element: el, ownsReference: true)
    }
}

/// Discovers available media devices on the system.
///
/// DeviceMonitor provides enumeration of video and audio devices such as
/// cameras, microphones, and speakers. Use it to build device selection
/// interfaces or to automatically configure pipelines.
///
/// ## Overview
///
/// Create a DeviceMonitor and call the appropriate method to list devices
/// by category. Each method returns an array of ``Device`` objects that
/// can be used to create pipeline elements.
///
/// ## Topics
///
/// ### Listing Devices
///
/// - ``videoSources()``
/// - ``audioSources()``
/// - ``audioSinks()``
/// - ``allDevices()``
///
/// ## Example
///
/// ```swift
/// let monitor = DeviceMonitor()
///
/// // List all cameras
/// print("Available cameras:")
/// for camera in monitor.videoSources() {
///     print("  - \(camera.displayName)")
///     if let caps = camera.caps {
///         print("    Caps: \(caps)")
///     }
/// }
///
/// // List all microphones
/// print("Available microphones:")
/// for mic in monitor.audioSources() {
///     print("  - \(mic.displayName)")
/// }
/// ```
///
/// ## Creating a Pipeline from a Device
///
/// ```swift
/// let monitor = DeviceMonitor()
///
/// if let camera = monitor.videoSources().first {
///     // Create element from device
///     if let source = camera.createElement(name: "cam") {
///         // Build pipeline manually
///         let pipeline = try Pipeline("fakesink name=sink")
///         pipeline.add(source)
///
///         if let sink = pipeline.element(named: "sink") {
///             source.link(to: sink)
///         }
///
///         try pipeline.play()
///     }
/// }
/// ```
///
/// ## Linux Device Example
///
/// ```swift
/// let monitor = DeviceMonitor()
///
/// for camera in monitor.videoSources() {
///     print("Camera: \(camera.displayName)")
///     if let path = camera.property("device.path") {
///         print("  Path: \(path)")  // e.g., "/dev/video0"
///     }
/// }
/// ```
public final class DeviceMonitor: @unchecked Sendable {

    /// Initialize a new device monitor.
    ///
    /// GStreamer must be initialized before creating a DeviceMonitor.
    public init() {
        // Ensure GStreamer is initialized
        try? GStreamer.ensureInitialized()
    }

    /// Get all video source devices (cameras).
    ///
    /// - Returns: Array of video source devices.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cameras = DeviceMonitor().videoSources()
    /// for camera in cameras {
    ///     print("Camera: \(camera.displayName)")
    /// }
    /// ```
    public func videoSources() -> [Device] {
        devices(withClass: "Video/Source")
    }

    /// Get all audio source devices (microphones).
    ///
    /// - Returns: Array of audio source devices.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let mics = DeviceMonitor().audioSources()
    /// for mic in mics {
    ///     print("Microphone: \(mic.displayName)")
    /// }
    /// ```
    public func audioSources() -> [Device] {
        devices(withClass: "Audio/Source")
    }

    /// Get all audio sink devices (speakers, headphones).
    ///
    /// - Returns: Array of audio sink devices.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let speakers = DeviceMonitor().audioSinks()
    /// for speaker in speakers {
    ///     print("Speaker: \(speaker.displayName)")
    /// }
    /// ```
    public func audioSinks() -> [Device] {
        devices(withClass: "Audio/Sink")
    }

    /// Get all available devices.
    ///
    /// - Returns: Array of all discovered devices.
    public func allDevices() -> [Device] {
        devices(withClass: nil)
    }

    /// Get devices matching a specific class.
    ///
    /// - Parameter deviceClass: The device class filter (e.g., "Video/Source"),
    ///   or `nil` for all devices.
    /// - Returns: Array of matching devices.
    private func devices(withClass deviceClass: String?) -> [Device] {
        guard let monitor = swift_gst_device_monitor_new() else {
            return []
        }
        defer { swift_gst_device_monitor_unref(monitor) }

        // Add filter
        _ = swift_gst_device_monitor_add_filter(monitor, deviceClass, nil)

        // Start monitoring
        guard swift_gst_device_monitor_start(monitor) != 0 else {
            return []
        }
        defer { swift_gst_device_monitor_stop(monitor) }

        // Get devices
        guard let deviceList = swift_gst_device_monitor_get_devices(monitor) else {
            return []
        }

        var result: [Device] = []
        var current: UnsafeMutablePointer<GList>? = deviceList

        while let node = current {
            if let devicePtr = node.pointee.data?.assumingMemoryBound(to: GstDevice.self) {
                // Take ownership by ref'ing before the list is freed
                gst_object_ref(devicePtr)
                result.append(Device(device: devicePtr))
            }
            current = node.pointee.next
        }

        swift_gst_device_list_free(deviceList)
        return result
    }
}
