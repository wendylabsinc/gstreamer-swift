import CGStreamer
import CGStreamerShim

/// GStreamer capabilities (media type description).
///
/// Caps describe the type of media data that can flow between elements.
/// They specify properties like resolution, format, and framerate.
///
/// ## Overview
///
/// Capabilities (caps) are used to negotiate the media format between
/// pipeline elements. They can be used as filters to constrain the
/// negotiated format.
///
/// ## Topics
///
/// ### Creating Caps
///
/// - ``init(_:)``
///
/// ### Properties
///
/// - ``description``
///
/// ## Example
///
/// ```swift
/// // Create caps from a string
/// let caps = try Caps("video/x-raw,format=BGRA,width=1920,height=1080")
/// print(caps.description)
/// // "video/x-raw, format=(string)BGRA, width=(int)1920, height=(int)1080"
/// ```
///
/// ## Common Caps Formats
///
/// ### Video Caps
///
/// ```swift
/// // Raw video with specific format and size
/// let videoCaps = try Caps("video/x-raw,format=BGRA,width=640,height=480")
///
/// // With framerate
/// let fpsCaps = try Caps("video/x-raw,format=BGRA,width=1920,height=1080,framerate=30/1")
///
/// // H.264 encoded video
/// let h264Caps = try Caps("video/x-h264,stream-format=byte-stream")
/// ```
///
/// ### Audio Caps
///
/// ```swift
/// // Raw audio
/// let audioCaps = try Caps("audio/x-raw,format=S16LE,rate=44100,channels=2")
///
/// // AAC encoded audio
/// let aacCaps = try Caps("audio/mpeg,mpegversion=4")
/// ```
///
/// ## Using Caps in Pipelines
///
/// Caps can be specified inline in pipeline descriptions:
///
/// ```swift
/// let pipeline = try Pipeline("""
///     videotestsrc ! \
///     video/x-raw,format=BGRA,width=640,height=480,framerate=30/1 ! \
///     appsink name=sink
///     """)
/// ```
///
/// Or use a capsfilter element:
///
/// ```swift
/// let pipeline = try Pipeline("""
///     videotestsrc ! \
///     capsfilter caps="video/x-raw,format=BGRA" ! \
///     appsink name=sink
///     """)
/// ```
public struct Caps: Sendable, CustomStringConvertible {
    /// The underlying GstCaps pointer wrapped in a reference type for memory management.
    private let storage: Storage

    /// Reference type to handle GstCaps memory management.
    private final class Storage: @unchecked Sendable {
        let caps: UnsafeMutablePointer<GstCaps>
        let ownsReference: Bool

        init(caps: UnsafeMutablePointer<GstCaps>, ownsReference: Bool) {
            self.caps = caps
            self.ownsReference = ownsReference
        }

        deinit {
            if ownsReference {
                swift_gst_caps_unref(caps)
            }
        }
    }

    /// The underlying GstCaps pointer.
    internal var caps: UnsafeMutablePointer<GstCaps> {
        storage.caps
    }

    /// Create caps from a string description.
    ///
    /// The string uses GStreamer's caps syntax for describing media types.
    ///
    /// - Parameter description: The caps string.
    /// - Throws: ``GStreamerError/capsParseFailed(_:)`` if the string is invalid.
    ///
    /// ## Format
    ///
    /// Caps strings have the format: `media-type,property=value,property=value,...`
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Video caps
    /// let video = try Caps("video/x-raw,format=BGRA,width=1920,height=1080")
    ///
    /// // Audio caps
    /// let audio = try Caps("audio/x-raw,format=S16LE,rate=48000,channels=2")
    ///
    /// // Encoded video
    /// let h264 = try Caps("video/x-h264,profile=high")
    /// ```
    ///
    /// ## Common Properties
    ///
    /// | Property | Description | Example |
    /// |----------|-------------|---------|
    /// | format | Pixel/sample format | BGRA, NV12, S16LE |
    /// | width | Video width | 1920 |
    /// | height | Video height | 1080 |
    /// | framerate | Frame rate fraction | 30/1, 60/1 |
    /// | rate | Audio sample rate | 44100, 48000 |
    /// | channels | Audio channels | 2 (stereo) |
    public init(_ description: String) throws {
        guard let caps = swift_gst_caps_from_string(description) else {
            throw GStreamerError.capsParseFailed(description)
        }
        self.storage = Storage(caps: caps, ownsReference: true)
    }

    /// Create a wrapper from an existing GstCaps pointer.
    ///
    /// - Parameters:
    ///   - caps: The GstCaps pointer.
    ///   - ownsReference: Whether to take ownership of the reference.
    internal init(caps: UnsafeMutablePointer<GstCaps>, ownsReference: Bool = true) {
        self.storage = Storage(caps: caps, ownsReference: ownsReference)
    }

    /// A string representation of the caps.
    ///
    /// Returns the full caps string including type annotations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let caps = try Caps("video/x-raw,format=BGRA,width=640")
    /// print(caps.description)
    /// // "video/x-raw, format=(string)BGRA, width=(int)640"
    /// ```
    public var description: String {
        GLibString.takeOwnership(swift_gst_caps_to_string(caps)) ?? ""
    }
}
