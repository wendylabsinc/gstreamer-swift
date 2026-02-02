/// Video pixel formats supported by GStreamer.
///
/// PixelFormat represents the color format and memory layout of video frame data.
/// Different formats have different memory requirements and are suited for different
/// purposes.
///
/// ## Overview
///
/// When processing video frames, the pixel format determines how to interpret
/// the raw bytes. Common formats include BGRA (common on Apple platforms),
/// RGBA, and various YUV formats used by video codecs.
///
/// ## Topics
///
/// ### Packed RGB Formats
///
/// - ``bgra``
/// - ``rgba``
///
/// ### YUV Formats
///
/// - ``nv12``
/// - ``i420``
///
/// ### Grayscale
///
/// - ``gray8``
///
/// ### Other
///
/// - ``unknown(_:)``
///
/// ### Format Properties
///
/// - ``formatString``
/// - ``bytesPerPixel``
///
/// ## Example
///
/// ```swift
/// for await frame in sink.frames() {
///     switch frame.format {
///     case .bgra:
///         // Direct access to BGRA pixels
///         try frame.withMappedBytes { span in
///             span.withUnsafeBytes { buffer in
///                 for i in stride(from: 0, to: buffer.count, by: 4) {
///                     let b = buffer[i]     // Blue
///                     let g = buffer[i + 1] // Green
///                     let r = buffer[i + 2] // Red
///                     let a = buffer[i + 3] // Alpha
///                 }
///             }
///         }
///
///     case .nv12:
///         // Y plane followed by interleaved UV plane
///         print("NV12 format - common for H.264 decoded video")
///
///     case .unknown(let format):
///         print("Unknown format: \(format)")
///
///     default:
///         break
///     }
/// }
/// ```
///
/// ## Format Selection
///
/// Choose the appropriate format based on your use case:
///
/// | Format | Use Case |
/// |--------|----------|
/// | BGRA | macOS/iOS rendering, Metal textures |
/// | RGBA | Cross-platform, OpenGL textures |
/// | NV12 | Hardware video decode output |
/// | I420 | Video encoding, software processing |
/// | GRAY8 | Grayscale processing, edge detection |
///
/// ```swift
/// // Request BGRA for Metal rendering
/// let pipeline = try Pipeline("""
///     videotestsrc ! videoconvert ! \
///     video/x-raw,format=BGRA,width=1920,height=1080 ! \
///     appsink name=sink
///     """)
/// ```
public enum PixelFormat: Sendable, Hashable, CustomStringConvertible {
    /// 32-bit BGRA format (Blue, Green, Red, Alpha).
    ///
    /// This is the native format for macOS and iOS Core Graphics.
    /// Each pixel is 4 bytes, with blue in the lowest address.
    ///
    /// Memory layout: `[B][G][R][A] [B][G][R][A] ...`
    case bgra

    /// 32-bit RGBA format (Red, Green, Blue, Alpha).
    ///
    /// Common format for cross-platform applications and OpenGL.
    /// Each pixel is 4 bytes, with red in the lowest address.
    ///
    /// Memory layout: `[R][G][B][A] [R][G][B][A] ...`
    case rgba

    /// YUV 4:2:0 semi-planar format.
    ///
    /// Common output format from hardware video decoders (H.264, HEVC).
    /// Y plane followed by interleaved UV plane at half resolution.
    ///
    /// Memory layout:
    /// - Y plane: `[Y0][Y1][Y2][Y3]...` (full resolution)
    /// - UV plane: `[U0][V0][U1][V1]...` (half width, half height)
    case nv12

    /// YUV 4:2:0 planar format (also known as YV12).
    ///
    /// Three separate planes for Y, U, and V components.
    /// Common for video encoding and software processing.
    ///
    /// Memory layout:
    /// - Y plane: full resolution
    /// - U plane: half width, half height
    /// - V plane: half width, half height
    case i420

    /// 8-bit grayscale format.
    ///
    /// Single channel, one byte per pixel.
    /// Useful for computer vision tasks like edge detection.
    ///
    /// Memory layout: `[G0][G1][G2][G3]...`
    case gray8

    /// Unknown or unsupported format.
    ///
    /// Contains the original format string from GStreamer.
    /// You may need to add a `videoconvert` element to convert
    /// to a supported format.
    case unknown(String)

    /// Initialize from a GStreamer format string.
    ///
    /// - Parameter string: The format name (e.g., "BGRA", "NV12").
    ///
    /// ## Example
    ///
    /// ```swift
    /// let format = PixelFormat(string: "BGRA")
    /// // format == .bgra
    ///
    /// let unknown = PixelFormat(string: "CUSTOM")
    /// // unknown == .unknown("CUSTOM")
    /// ```
    public init(string: String) {
        switch string.uppercased() {
        case "BGRA": self = .bgra
        case "RGBA": self = .rgba
        case "NV12": self = .nv12
        case "I420": self = .i420
        case "GRAY8": self = .gray8
        default: self = .unknown(string)
        }
    }

    /// The GStreamer format string.
    ///
    /// Use this when constructing caps filters in pipeline descriptions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let format = PixelFormat.bgra
    /// print(format.formatString) // "BGRA"
    ///
    /// let caps = "video/x-raw,format=\(format.formatString)"
    /// // "video/x-raw,format=BGRA"
    /// ```
    public var formatString: String {
        switch self {
        case .bgra: return "BGRA"
        case .rgba: return "RGBA"
        case .nv12: return "NV12"
        case .i420: return "I420"
        case .gray8: return "GRAY8"
        case .unknown(let s): return s
        }
    }

    /// The number of bytes per pixel for packed formats.
    ///
    /// For planar formats (NV12, I420), this returns the bytes per sample
    /// in the Y plane.
    ///
    /// | Format | Bytes per Pixel |
    /// |--------|-----------------|
    /// | BGRA | 4 |
    /// | RGBA | 4 |
    /// | NV12 | 1 (Y plane) |
    /// | I420 | 1 (Y plane) |
    /// | GRAY8 | 1 |
    /// | unknown | 0 |
    ///
    /// ## Example
    ///
    /// ```swift
    /// let format = PixelFormat.bgra
    /// let bufferSize = width * height * format.bytesPerPixel
    /// // For 1920x1080 BGRA: 1920 * 1080 * 4 = 8,294,400 bytes
    /// ```
    public var bytesPerPixel: Int {
        switch self {
        case .bgra, .rgba: return 4
        case .gray8: return 1
        case .nv12, .i420: return 1 // Planar format - this is per-plane for Y
        case .unknown: return 0
        }
    }

    /// A human-readable description of the pixel format.
    public var description: String {
        formatString
    }
}
