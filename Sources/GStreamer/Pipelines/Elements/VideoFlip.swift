/// The transformation method for video flip/rotate operations.
public enum VideoFlipMethod: Int, Sendable {
    /// No rotation
    case none = 0
    /// Rotate 90 degrees clockwise
    case rotate90 = 1
    /// Rotate 180 degrees
    case rotate180 = 2
    /// Rotate 90 degrees counter-clockwise (270 clockwise)
    case rotate270 = 3
    /// Flip horizontally (mirror)
    case horizontalFlip = 4
    /// Flip vertically
    case verticalFlip = 5
    /// Flip across upper-left to lower-right diagonal
    case upperLeftDiagonal = 6
    /// Flip across upper-right to lower-left diagonal
    case upperRightDiagonal = 7
    /// Automatic based on image-orientation tag
    case automatic = 8
}

// MARK: - Dimension-Preserving Flips

/// A pipeline element that mirrors video horizontally (left-right).
///
/// This operation preserves frame dimensions and type information.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func mirroredPipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     VideoTestSource()
///     RawVideoFormat(layout: BGRA<1920, 1080>.self)
///     VideoMirror()  // Dimensions preserved in type
/// }
/// ```
public struct VideoMirror<Layout: PixelLayoutProtocol>: VideoPipelineConvert {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = _VideoFrame<Layout>

    public var pipeline: String { "videoflip method=4" }

    public init() {}
}

/// A pipeline element that flips video vertically (top-bottom).
///
/// This operation preserves frame dimensions and type information.
public struct VideoVerticalFlip<Layout: PixelLayoutProtocol>: VideoPipelineConvert {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = _VideoFrame<Layout>

    public var pipeline: String { "videoflip method=5" }

    public init() {}
}

/// A pipeline element that rotates video 180 degrees.
///
/// This operation preserves frame dimensions and type information.
public struct VideoRotate180<Layout: PixelLayoutProtocol>: VideoPipelineConvert {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = _VideoFrame<Layout>

    public var pipeline: String { "videoflip method=2" }

    public init() {}
}

// MARK: - Dimension-Swapping Rotations (type-safe)

/// A pipeline element that rotates video 90 degrees clockwise.
///
/// This operation swaps width and height. The output type has swapped dimensions:
/// `_VideoFrame<BGRA<1920, 1080>>` → `_VideoFrame<BGRA<1080, 1920>>`
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func rotatedPipeline() -> PartialPipeline<_VideoFrame<BGRA<1080, 1920>>> {
///     VideoTestSource()
///     RawVideoFormat(layout: BGRA<1920, 1080>.self)
///     VideoRotate90()  // Type becomes BGRA<1080, 1920>
/// }
/// ```
public struct VideoRotate90<Layout: PixelLayoutProtocol>: VideoPipelineConvert {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = _VideoFrame<Layout.Rotated>

    public var pipeline: String { "videoflip method=1" }

    public init() {}
}

/// A pipeline element that rotates video 90 degrees counter-clockwise (270 clockwise).
///
/// This operation swaps width and height. The output type has swapped dimensions:
/// `_VideoFrame<BGRA<1920, 1080>>` → `_VideoFrame<BGRA<1080, 1920>>`
public struct VideoRotate270<Layout: PixelLayoutProtocol>: VideoPipelineConvert {
    public typealias VideoFrameInput = _VideoFrame<Layout>
    public typealias VideoFrameOutput = _VideoFrame<Layout.Rotated>

    public var pipeline: String { "videoflip method=3" }

    public init() {}
}

// MARK: - Generic VideoFlip (untyped, for flexibility)

/// A pipeline element that flips or rotates video frames.
///
/// For dimension-preserving operations with type safety, prefer:
/// - ``VideoMirror`` for horizontal flip
/// - ``VideoVerticalFlip`` for vertical flip
/// - ``VideoRotate180`` for 180° rotation
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func rotatedPipeline() -> PartialPipeline<VideoFrame> {
///     VideoTestSource()
///     VideoFlip(.rotate90)
/// }
/// ```
public struct VideoFlip: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let method: VideoFlipMethod

    public var pipeline: String {
        "videoflip method=\(method.rawValue)"
    }

    /// Create a VideoFlip element with a specific transformation.
    ///
    /// - Parameter method: The transformation to apply.
    public init(_ method: VideoFlipMethod) {
        self.method = method
    }

    // MARK: - Convenience initializers

    /// Rotate 90 degrees clockwise.
    public static let rotate90 = VideoFlip(.rotate90)

    /// Rotate 180 degrees.
    public static let rotate180 = VideoFlip(.rotate180)

    /// Rotate 90 degrees counter-clockwise.
    public static let rotate270 = VideoFlip(.rotate270)

    /// Mirror horizontally.
    public static let horizontalFlip = VideoFlip(.horizontalFlip)

    /// Flip vertically.
    public static let verticalFlip = VideoFlip(.verticalFlip)

    /// Auto-rotate based on image orientation metadata.
    public static let automatic = VideoFlip(.automatic)
}
