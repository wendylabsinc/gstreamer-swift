/// Audio sample formats supported by GStreamer.
///
/// AudioFormat represents the sample format and encoding of audio data.
/// Different formats have different precision, memory requirements, and use cases.
///
/// ## Overview
///
/// When processing audio buffers, the format determines how to interpret
/// the raw bytes. Common formats include signed 16-bit integers (S16LE)
/// for general audio and 32-bit floats (F32LE) for audio processing.
///
/// ## Topics
///
/// ### Integer Formats
///
/// - ``s16le``
/// - ``s32le``
/// - ``u8``
///
/// ### Floating Point Formats
///
/// - ``f32le``
/// - ``f64le``
///
/// ### Other
///
/// - ``unknown(_:)``
///
/// ### Format Properties
///
/// - ``formatString``
/// - ``bytesPerSample``
///
/// ## Example
///
/// ```swift
/// for await buffer in audioSink.buffers() {
///     switch buffer.format {
///     case .s16le:
///         try buffer.withMappedBytes { span in
///             span.withUnsafeBytes { bytes in
///                 // Process 16-bit signed samples
///                 let samples = bytes.bindMemory(to: Int16.self)
///                 for sample in samples {
///                     let normalized = Float(sample) / Float(Int16.max)
///                     // Process normalized audio...
///                 }
///             }
///         }
///
///     case .f32le:
///         try buffer.withMappedBytes { span in
///             span.withUnsafeBytes { bytes in
///                 // Process 32-bit float samples directly
///                 let samples = bytes.bindMemory(to: Float.self)
///                 for sample in samples {
///                     // Already normalized -1.0 to 1.0
///                 }
///             }
///         }
///
///     default:
///         break
///     }
/// }
/// ```
///
/// ## Format Selection
///
/// | Format | Use Case |
/// |--------|----------|
/// | S16LE | Standard audio, speech recognition |
/// | S32LE | High-resolution audio |
/// | F32LE | Audio processing, DSP |
/// | F64LE | Scientific/precision audio |
/// | U8 | Low-quality audio, compatibility |
public enum AudioFormat: Sendable, Hashable, CustomStringConvertible {
    /// Signed 16-bit little-endian integer.
    ///
    /// The most common audio format. Range: -32768 to 32767.
    /// Used by most audio APIs and speech recognition systems.
    case s16le

    /// Signed 32-bit little-endian integer.
    ///
    /// High-resolution audio. Range: -2147483648 to 2147483647.
    case s32le

    /// Unsigned 8-bit integer.
    ///
    /// Low-quality audio. Range: 0 to 255 (128 = silence).
    case u8

    /// 32-bit little-endian floating point.
    ///
    /// Preferred for audio processing. Range: -1.0 to 1.0.
    /// No clipping during intermediate calculations.
    case f32le

    /// 64-bit little-endian floating point.
    ///
    /// High-precision audio processing. Range: -1.0 to 1.0.
    case f64le

    /// Unknown or unsupported format.
    case unknown(String)

    /// Initialize from a GStreamer format string.
    ///
    /// - Parameter string: The format name (e.g., "S16LE", "F32LE").
    public init(string: String) {
        switch string.uppercased() {
        case "S16LE": self = .s16le
        case "S32LE": self = .s32le
        case "U8": self = .u8
        case "F32LE": self = .f32le
        case "F64LE": self = .f64le
        default: self = .unknown(string)
        }
    }

    /// The GStreamer format string.
    public var formatString: String {
        switch self {
        case .s16le: return "S16LE"
        case .s32le: return "S32LE"
        case .u8: return "U8"
        case .f32le: return "F32LE"
        case .f64le: return "F64LE"
        case .unknown(let s): return s
        }
    }

    /// The number of bytes per sample for this format.
    ///
    /// | Format | Bytes per Sample |
    /// |--------|------------------|
    /// | S16LE | 2 |
    /// | S32LE | 4 |
    /// | U8 | 1 |
    /// | F32LE | 4 |
    /// | F64LE | 8 |
    public var bytesPerSample: Int {
        switch self {
        case .s16le: return 2
        case .s32le: return 4
        case .u8: return 1
        case .f32le: return 4
        case .f64le: return 8
        case .unknown: return 0
        }
    }

    /// A human-readable description of the audio format.
    public var description: String {
        formatString
    }
}
