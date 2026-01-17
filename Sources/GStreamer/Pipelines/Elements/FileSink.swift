/// A pipeline sink that writes to a file.
///
/// FileSink writes raw data to a file. For encoded video/audio output,
/// combine with an encoder and muxer.
///
/// ## Example
///
/// ```swift
/// // Raw video to file (large!)
/// let pipeline = try Pipeline("""
///     videotestsrc num-buffers=100 ! \
///     video/x-raw,format=I420,width=320,height=240 ! \
///     filesink location=/tmp/raw.yuv
/// """)
/// ```
public struct FileSink: VideoSink {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = Never

    private let location: String
    private let append: Bool

    public var pipeline: String {
        var options = ["filesink"]
        options.append("location=\"\(location)\"")
        if append {
            options.append("append=true")
        }
        return options.joined(separator: " ")
    }

    /// Create a FileSink.
    ///
    /// - Parameters:
    ///   - location: Path to the output file.
    ///   - append: Whether to append to existing file (default false).
    public init(location: String, append: Bool = false) {
        self.location = location
        self.append = append
    }
}

/// A pipeline sink that writes to segmented files.
///
/// SplitMuxSink automatically splits output into multiple files based on
/// duration or size, useful for recording.
///
/// ## Example
///
/// ```swift
/// // Record to 10-second segments
/// let sink = SplitMuxSink(
///     location: "/tmp/video%05d.mp4",
///     maxDuration: .seconds(10)
/// )
/// ```
public struct SplitMuxSink: VideoSink {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = Never

    private let location: String
    private let maxDurationNs: UInt64?
    private let maxSizeBytes: UInt64?
    private let muxer: String?

    public var pipeline: String {
        var options = ["splitmuxsink"]
        options.append("location=\"\(location)\"")
        if let maxDurationNs {
            options.append("max-size-time=\(maxDurationNs)")
        }
        if let maxSizeBytes {
            options.append("max-size-bytes=\(maxSizeBytes)")
        }
        if let muxer {
            options.append("muxer=\(muxer)")
        }
        return options.joined(separator: " ")
    }

    /// Create a SplitMuxSink.
    ///
    /// - Parameters:
    ///   - location: Path pattern with %d for segment number (e.g., "video%05d.mp4").
    ///   - maxDuration: Maximum duration per segment.
    ///   - maxSizeBytes: Maximum size per segment in bytes.
    ///   - muxer: Muxer element to use (e.g., "mp4mux", "matroskamux").
    public init(
        location: String,
        maxDuration: Duration? = nil,
        maxSizeBytes: UInt64? = nil,
        muxer: String? = nil
    ) {
        self.location = location
        self.maxDurationNs = maxDuration.map { UInt64($0.components.seconds) * 1_000_000_000 + UInt64($0.components.attoseconds / 1_000_000_000) }
        self.maxSizeBytes = maxSizeBytes
        self.muxer = muxer
    }
}

// MARK: - Encoders

/// H.264 video encoder.
public struct X264Encoder: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    /// Encoding speed preset.
    public enum Preset: String, Sendable {
        case ultrafast
        case superfast
        case veryfast
        case faster
        case fast
        case medium
        case slow
        case slower
        case veryslow
        case placebo
    }

    /// Encoding tune option.
    public enum Tune: String, Sendable {
        case film
        case animation
        case grain
        case stillimage
        case fastdecode
        case zerolatency
    }

    private let bitrate: Int?
    private let preset: Preset?
    private let tune: Tune?
    private let keyframeInterval: Int?

    public var pipeline: String {
        var options = ["x264enc"]
        if let bitrate {
            options.append("bitrate=\(bitrate)")
        }
        if let preset {
            options.append("speed-preset=\(preset.rawValue)")
        }
        if let tune {
            options.append("tune=\(tune.rawValue)")
        }
        if let keyframeInterval {
            options.append("key-int-max=\(keyframeInterval)")
        }
        return options.joined(separator: " ")
    }

    /// Create an X264 encoder.
    ///
    /// - Parameters:
    ///   - bitrate: Target bitrate in kbps.
    ///   - preset: Encoding speed/quality preset.
    ///   - tune: Encoding tune for specific content types.
    ///   - keyframeInterval: Maximum frames between keyframes.
    public init(
        bitrate: Int? = nil,
        preset: Preset? = nil,
        tune: Tune? = nil,
        keyframeInterval: Int? = nil
    ) {
        self.bitrate = bitrate
        self.preset = preset
        self.tune = tune
        self.keyframeInterval = keyframeInterval
    }

    /// Fast encoding preset suitable for real-time streaming.
    public static let streaming = X264Encoder(preset: .veryfast, tune: .zerolatency)

    /// High quality preset for offline encoding.
    public static let highQuality = X264Encoder(preset: .slow)
}

/// JPEG image encoder.
public struct JPEGEncoder: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let quality: Int

    public var pipeline: String {
        "jpegenc quality=\(quality)"
    }

    /// Create a JPEG encoder.
    ///
    /// - Parameter quality: JPEG quality (0-100, default 85).
    public init(quality: Int = 85) {
        self.quality = max(0, min(100, quality))
    }
}

/// PNG image encoder.
public struct PNGEncoder: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let compressionLevel: Int

    public var pipeline: String {
        "pngenc compression-level=\(compressionLevel)"
    }

    /// Create a PNG encoder.
    ///
    /// - Parameter compressionLevel: Compression level (0-9, default 6).
    public init(compressionLevel: Int = 6) {
        self.compressionLevel = max(0, min(9, compressionLevel))
    }
}

// MARK: - Muxers

/// MP4 container muxer.
public struct MP4Mux: VideoPipelineElement {
    private let faststart: Bool

    public var pipeline: String {
        var options = ["mp4mux"]
        if faststart {
            options.append("faststart=true")
        }
        return options.joined(separator: " ")
    }

    /// Create an MP4 muxer.
    ///
    /// - Parameter faststart: Move index to start for streaming (default true).
    public init(faststart: Bool = true) {
        self.faststart = faststart
    }
}

/// Matroska (MKV) container muxer.
public struct MatroskaMux: VideoPipelineElement {
    public var pipeline: String { "matroskamux" }
    public init() {}
}

/// AVI container muxer.
public struct AVIMux: VideoPipelineElement {
    public var pipeline: String { "avimux" }
    public init() {}
}
