/// A camera source that automatically selects the appropriate platform backend.
///
/// This provides a cross-platform camera source:
/// - macOS/iOS: Uses avfvideosrc (AVFoundation)
/// - Linux: Uses v4l2src (Video4Linux2)
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func cameraPipeline() -> PartialPipeline<VideoFrame> {
///     CameraSource()
///     VideoConvert()
/// }
/// ```
public struct CameraSource: VideoPipelineSource {
    public typealias VideoFrameOutput = VideoFrame

    private let deviceIndex: Int?
    private let deviceName: String?

    public var pipeline: String {
        #if os(macOS) || os(iOS)
        return avfPipeline
        #elseif os(Linux)
        return v4l2Pipeline
        #else
        return "videotestsrc"  // Fallback for unsupported platforms
        #endif
    }

    private var avfPipeline: String {
        var options = ["avfvideosrc"]
        if let deviceIndex {
            options.append("device-index=\(deviceIndex)")
        }
        return options.joined(separator: " ")
    }

    private var v4l2Pipeline: String {
        var options = ["v4l2src"]
        if let deviceName {
            options.append("device=\(deviceName)")
        } else if let deviceIndex {
            options.append("device=/dev/video\(deviceIndex)")
        }
        return options.joined(separator: " ")
    }

    /// Create a CameraSource using the default camera.
    public init() {
        self.deviceIndex = nil
        self.deviceName = nil
    }

    /// Create a CameraSource with a specific device index.
    ///
    /// - Parameter deviceIndex: The camera index (0 is typically the default camera).
    public init(deviceIndex: Int) {
        self.deviceIndex = deviceIndex
        self.deviceName = nil
    }

    /// Create a CameraSource with a specific device path (Linux only).
    ///
    /// - Parameter devicePath: The device path (e.g., "/dev/video0").
    public init(devicePath: String) {
        self.deviceIndex = nil
        self.deviceName = devicePath
    }
}

#if os(macOS) || os(iOS)
/// AVFoundation video source for macOS and iOS.
///
/// Provides access to cameras on Apple platforms.
public struct AVFoundationVideoSource: VideoPipelineSource {
    public typealias VideoFrameOutput = VideoFrame

    private let deviceIndex: Int?
    private let captureScreen: Bool
    private let captureScreenCursor: Bool

    public var pipeline: String {
        var options = ["avfvideosrc"]
        if let deviceIndex {
            options.append("device-index=\(deviceIndex)")
        }
        if captureScreen {
            options.append("capture-screen=true")
            if captureScreenCursor {
                options.append("capture-screen-cursor=true")
            }
        }
        return options.joined(separator: " ")
    }

    /// Create an AVFoundation source for the default camera.
    public init() {
        self.deviceIndex = nil
        self.captureScreen = false
        self.captureScreenCursor = false
    }

    /// Create an AVFoundation source for a specific camera.
    ///
    /// - Parameter deviceIndex: The camera index.
    public init(deviceIndex: Int) {
        self.deviceIndex = deviceIndex
        self.captureScreen = false
        self.captureScreenCursor = false
    }

    /// Create an AVFoundation source for screen capture.
    ///
    /// - Parameter includeCursor: Whether to include the cursor in the capture.
    public static func screenCapture(includeCursor: Bool = true) -> AVFoundationVideoSource {
        AVFoundationVideoSource(
            deviceIndex: nil,
            captureScreen: true,
            captureScreenCursor: includeCursor
        )
    }

    private init(deviceIndex: Int?, captureScreen: Bool, captureScreenCursor: Bool) {
        self.deviceIndex = deviceIndex
        self.captureScreen = captureScreen
        self.captureScreenCursor = captureScreenCursor
    }
}
#endif

#if os(Linux)
/// Video4Linux2 video source for Linux.
///
/// Provides access to cameras and capture devices on Linux.
public struct V4L2VideoSource: VideoPipelineSource {
    public typealias VideoFrameOutput = VideoFrame

    private let device: String

    public var pipeline: String {
        "v4l2src device=\(device)"
    }

    /// Create a V4L2 source for the default camera.
    public init() {
        self.device = "/dev/video0"
    }

    /// Create a V4L2 source for a specific device.
    ///
    /// - Parameter device: The device path (e.g., "/dev/video0").
    public init(device: String) {
        self.device = device
    }

    /// Create a V4L2 source for a device by index.
    ///
    /// - Parameter index: The device index (maps to /dev/videoN).
    public init(index: Int) {
        self.device = "/dev/video\(index)"
    }
}
#endif
