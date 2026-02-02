/// A fluent builder for constructing GStreamer capabilities (caps) strings.
///
/// CapsBuilder provides a type-safe, fluent API for constructing caps strings
/// that define media format constraints in pipelines.
///
/// - Note: This is an internal API. For public use, prefer the generic pipeline
///   elements like `RawVideoFormat<_VideoFrame<BGRA<1920, 1080>>>`.
internal struct CapsBuilder: Sendable {
    private var mediaType: String
    private var properties: [(key: String, value: String)]

    /// Create a builder with a custom media type.
    ///
    /// - Parameter mediaType: The media type (e.g., "video/x-raw", "audio/x-raw").
    init(mediaType: String) {
        self.mediaType = mediaType
        self.properties = []
    }

    /// Create a builder for raw video.
    static func video() -> CapsBuilder {
        CapsBuilder(mediaType: "video/x-raw")
    }

    /// Create a builder for raw audio.
    static func audio() -> CapsBuilder {
        CapsBuilder(mediaType: "audio/x-raw")
    }

    // MARK: - Video Properties

    /// Set the pixel format for video.
    ///
    /// - Parameter format: The pixel format.
    /// - Returns: The builder for chaining.
    func format(_ format: PixelFormat) -> CapsBuilder {
        property("format", format.formatString)
    }

    /// Set the video dimensions.
    ///
    /// - Parameters:
    ///   - width: The width in pixels.
    ///   - height: The height in pixels.
    /// - Returns: The builder for chaining.
    func size(width: Int, height: Int) -> CapsBuilder {
        self.property("width", String(width))
            .property("height", String(height))
    }

    /// Set the video width.
    ///
    /// - Parameter width: The width in pixels.
    /// - Returns: The builder for chaining.
    func width(_ width: Int) -> CapsBuilder {
        property("width", String(width))
    }

    /// Set the video height.
    ///
    /// - Parameter height: The height in pixels.
    /// - Returns: The builder for chaining.
    func height(_ height: Int) -> CapsBuilder {
        property("height", String(height))
    }

    /// Set the video framerate.
    ///
    /// - Parameters:
    ///   - numerator: The framerate numerator (e.g., 30 for 30fps).
    ///   - denominator: The framerate denominator (e.g., 1 for 30fps, 1001 for 29.97fps).
    /// - Returns: The builder for chaining.
    func framerate(_ numerator: Int, _ denominator: Int) -> CapsBuilder {
        property("framerate", "\(numerator)/\(denominator)")
    }

    // MARK: - Audio Properties

    /// Set the audio sample format.
    ///
    /// - Parameter format: The audio format.
    /// - Returns: The builder for chaining.
    func format(_ format: AudioFormat) -> CapsBuilder {
        property("format", format.formatString)
    }

    /// Set the audio sample rate.
    ///
    /// - Parameter rate: The sample rate in Hz (e.g., 44100, 48000).
    /// - Returns: The builder for chaining.
    func rate(_ rate: Int) -> CapsBuilder {
        property("rate", String(rate))
    }

    /// Set the number of audio channels.
    ///
    /// - Parameter channels: The number of channels (1 for mono, 2 for stereo).
    /// - Returns: The builder for chaining.
    func channels(_ channels: Int) -> CapsBuilder {
        property("channels", String(channels))
    }

    // MARK: - Generic Properties

    /// Add a custom property.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The property value.
    /// - Returns: The builder for chaining.
    func property(_ key: String, _ value: String) -> CapsBuilder {
        var copy = self
        copy.properties.append((key, value))
        return copy
    }

    /// Add a custom integer property.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The integer value.
    /// - Returns: The builder for chaining.
    func property(_ key: String, _ value: Int) -> CapsBuilder {
        property(key, String(value))
    }

    /// Add a custom boolean property.
    ///
    /// - Parameters:
    ///   - key: The property name.
    ///   - value: The boolean value.
    /// - Returns: The builder for chaining.
    func property(_ key: String, _ value: Bool) -> CapsBuilder {
        property(key, value ? "true" : "false")
    }

    // MARK: - Build

    /// Build the caps string.
    ///
    /// - Returns: The complete caps string.
    func build() -> String {
        if properties.isEmpty {
            return mediaType
        }
        let propsString = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(mediaType),\(propsString)"
    }

    /// Build a Caps object from this builder.
    ///
    /// - Returns: A Caps object.
    /// - Throws: ``GStreamerError/capsParseFailed(_:)`` if the caps string is invalid.
    func buildCaps() throws -> Caps {
        try Caps(build())
    }
}

// MARK: - CustomStringConvertible

extension CapsBuilder: CustomStringConvertible {
    var description: String {
        build()
    }
}

// MARK: - Common Presets

extension CapsBuilder {
    /// A preset for 1080p BGRA video at 30fps.
    static var hd1080pBGRA: CapsBuilder {
        video()
            .format(.bgra)
            .size(width: 1920, height: 1080)
            .framerate(30, 1)
    }

    /// A preset for 720p BGRA video at 30fps.
    static var hd720pBGRA: CapsBuilder {
        video()
            .format(.bgra)
            .size(width: 1280, height: 720)
            .framerate(30, 1)
    }

    /// A preset for 16kHz mono audio (common for speech recognition).
    static var speechRecognition: CapsBuilder {
        audio()
            .format(.s16le)
            .rate(16000)
            .channels(1)
    }

    /// A preset for CD-quality audio (44.1kHz stereo S16LE).
    static var cdQuality: CapsBuilder {
        audio()
            .format(.s16le)
            .rate(44100)
            .channels(2)
    }

    /// A preset for high-quality audio processing (48kHz stereo F32LE).
    static var highQualityAudio: CapsBuilder {
        audio()
            .format(.f32le)
            .rate(48000)
            .channels(2)
    }
}
