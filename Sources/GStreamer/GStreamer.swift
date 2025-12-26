import CGStreamer
import CGStreamerShim
import Synchronization

/// Main GStreamer interface for initialization and version information.
///
/// GStreamer auto-initializes when you create your first pipeline, so explicit
/// initialization is optional. Call ``initialize(_:)`` only if you need custom
/// configuration like plugin paths.
///
/// ## Overview
///
/// The `GStreamer` enum provides the entry point for using GStreamer in your application.
/// It handles initialization, version queries, and global state management.
///
/// ## Topics
///
/// ### Initialization
///
/// - ``initialize(_:)``
/// - ``Configuration``
/// - ``isInitialized``
///
/// ### Version Information
///
/// - ``versionString``
/// - ``version``
/// - ``Version``
///
/// ## Example
///
/// ```swift
/// import GStreamer
///
/// // Just create a pipeline - GStreamer auto-initializes
/// let pipeline = try Pipeline("videotestsrc ! autovideosink")
/// try pipeline.play()
///
/// // Or initialize explicitly for custom configuration
/// var config = GStreamer.Configuration()
/// config.pluginPaths = ["/opt/gstreamer/plugins"]
/// try GStreamer.initialize(config)
/// ```
public enum GStreamer {

    /// Configuration options for GStreamer initialization.
    ///
    /// Use this to customize how GStreamer initializes, such as specifying
    /// plugin search paths or enabling lazy initialization.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var config = GStreamer.Configuration()
    /// config.pluginPaths = ["/opt/gstreamer/plugins"]
    /// config.lazyInitialize = true
    /// try GStreamer.initialize(config)
    /// ```
    public struct Configuration: Sendable {
        /// Additional paths to search for GStreamer plugins.
        ///
        /// These paths are added to `GST_PLUGIN_PATH` environment variable.
        /// Existing paths are not overwritten.
        public var pluginPaths: [String] = []

        /// If `true`, defer actual initialization until first pipeline creation.
        ///
        /// This can speed up application startup if GStreamer isn't immediately needed.
        public var lazyInitialize: Bool = false

        /// Creates a default configuration.
        public init() {}
    }

    /// Thread-safe state tracking using Mutex.
    private static let state = Mutex<InitState>(.notInitialized)

    private enum InitState {
        case notInitialized
        case initialized
        case lazyPending(Configuration)
    }

    /// Initialize GStreamer with the given configuration.
    ///
    /// This must be called once per process before creating any pipelines.
    /// Calling multiple times is safe and will be ignored after the first call.
    ///
    /// - Parameter config: Configuration options for initialization.
    /// - Throws: ``GStreamerError/initializationFailed(_:)`` if initialization fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple initialization
    /// try GStreamer.initialize()
    ///
    /// // With custom configuration
    /// var config = GStreamer.Configuration()
    /// config.pluginPaths = ["/custom/plugins"]
    /// try GStreamer.initialize(config)
    /// ```
    public static func initialize(_ config: Configuration = .init()) throws {
        try state.withLock { initState in
            switch initState {
            case .initialized:
                return // Already initialized
            case .lazyPending:
                return // Already configured for lazy init
            case .notInitialized:
                break
            }

            if config.lazyInitialize {
                initState = .lazyPending(config)
                return
            }

            try performInitialization(config)
            initState = .initialized
        }
    }

    /// Ensures GStreamer is initialized, auto-initializing with defaults if needed.
    ///
    /// This is called automatically when creating pipelines, device monitors, etc.
    /// You only need to call ``initialize(_:)`` explicitly if you want custom configuration.
    internal static func ensureInitialized() throws {
        try state.withLock { initState in
            switch initState {
            case .initialized:
                return
            case .lazyPending(let config):
                try performInitialization(config)
                initState = .initialized
            case .notInitialized:
                // Auto-initialize with default configuration
                try performInitialization(Configuration())
                initState = .initialized
            }
        }
    }

    private static func performInitialization(_ config: Configuration) throws {
        // Set plugin paths if provided
        for path in config.pluginPaths {
            setenv("GST_PLUGIN_PATH", path, 0) // 0 = don't overwrite if exists
        }

        guard swift_gst_init() != 0 else {
            throw GStreamerError.initializationFailed("gst_init_check failed")
        }
    }

    /// Whether GStreamer is currently initialized.
    ///
    /// Returns `true` if ``initialize(_:)`` has been called successfully.
    public static var isInitialized: Bool {
        state.withLock { initState in
            if case .initialized = initState {
                return true
            }
            return false
        }
    }

    /// The GStreamer version as a formatted string.
    ///
    /// Returns just the version number (e.g., "1.24.6"), not the full
    /// "GStreamer 1.24.6" string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// print(GStreamer.versionString) // "1.24.6"
    /// ```
    public static var versionString: String {
        guard let cString = swift_gst_version_string() else {
            return "Unknown"
        }
        defer { g_free(cString) }
        // Extract just the version number from "GStreamer 1.x.y"
        let full = String(cString: cString)
        if let range = full.range(of: "GStreamer ") {
            return String(full[range.upperBound...])
        }
        return full
    }

    /// Detailed version information with major, minor, micro, and nano components.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let v = GStreamer.version
    /// print("Major: \(v.major), Minor: \(v.minor)")
    /// ```
    public struct Version: Sendable, CustomStringConvertible {
        /// Major version number (e.g., 1 in "1.24.6").
        public let major: UInt
        /// Minor version number (e.g., 24 in "1.24.6").
        public let minor: UInt
        /// Micro version number (e.g., 6 in "1.24.6").
        public let micro: UInt
        /// Nano version number (typically 0 for releases).
        public let nano: UInt

        /// String representation of the version.
        public var description: String {
            if nano > 0 {
                return "\(major).\(minor).\(micro).\(nano)"
            }
            return "\(major).\(minor).\(micro)"
        }
    }

    /// The GStreamer version components.
    ///
    /// Use this to check version compatibility or for detailed version information.
    public static var version: Version {
        Version(
            major: UInt(swift_gst_version_major()),
            minor: UInt(swift_gst_version_minor()),
            micro: UInt(swift_gst_version_micro()),
            nano: UInt(swift_gst_version_nano())
        )
    }
}
