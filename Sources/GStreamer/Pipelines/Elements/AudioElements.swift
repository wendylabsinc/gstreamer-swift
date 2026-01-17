/// A pipeline element that converts between audio formats.
///
/// AudioConvert handles conversion between different sample formats,
/// channel layouts, and sample rates when combined with ``AudioResample``.
public struct AudioConvert: VideoPipelineElement {
    public var pipeline: String { "audioconvert" }
    public init() {}
}

/// A pipeline element that resamples audio to a different sample rate.
public struct AudioResample: VideoPipelineElement {
    public var pipeline: String { "audioresample" }
    public init() {}
}

/// A pipeline element that adjusts audio volume.
///
/// ## Example
///
/// ```swift
/// // In a pipeline string
/// let pipeline = try Pipeline("audiotestsrc ! \(Volume(0.5).pipeline) ! autoaudiosink")
/// ```
public struct Volume: VideoPipelineElement {
    private let volume: Double
    private let mute: Bool

    public var pipeline: String {
        var options = ["volume"]
        options.append("volume=\(volume)")
        if mute {
            options.append("mute=true")
        }
        return options.joined(separator: " ")
    }

    /// Create a Volume element.
    ///
    /// - Parameters:
    ///   - volume: Volume level (0.0 = silent, 1.0 = 100%, 2.0 = 200%, etc.)
    ///   - mute: Whether to mute the audio.
    public init(_ volume: Double, mute: Bool = false) {
        self.volume = volume
        self.mute = mute
    }

    /// Muted volume.
    public static let muted = Volume(0.0, mute: true)

    /// Half volume.
    public static let half = Volume(0.5)

    /// Full volume (100%).
    public static let full = Volume(1.0)
}

/// A pipeline element that generates test audio.
public struct AudioTestSource: VideoPipelineElement {
    /// Test audio wave type.
    public enum Wave: Int, Sendable {
        case sine = 0
        case square = 1
        case saw = 2
        case triangle = 3
        case silence = 4
        case whitenoise = 5
        case pinknoise = 6
        case sineTable = 7
        case ticks = 8
        case gaussianNoise = 9
        case redNoise = 10
        case blueNoise = 11
        case violetNoise = 12
    }

    private let wave: Wave
    private let frequency: Double?
    private let numberOfBuffers: Int?

    public var pipeline: String {
        var options = ["audiotestsrc"]
        options.append("wave=\(wave.rawValue)")
        if let frequency {
            options.append("freq=\(frequency)")
        }
        if let numberOfBuffers {
            options.append("num-buffers=\(numberOfBuffers)")
        }
        return options.joined(separator: " ")
    }

    /// Create an AudioTestSource.
    ///
    /// - Parameters:
    ///   - wave: The type of test signal.
    ///   - frequency: Frequency in Hz for tonal waves (default 440Hz).
    ///   - numberOfBuffers: Number of buffers to produce before EOS.
    public init(wave: Wave = .sine, frequency: Double? = nil, numberOfBuffers: Int? = nil) {
        self.wave = wave
        self.frequency = frequency
        self.numberOfBuffers = numberOfBuffers
    }

    /// Silence source.
    public static let silence = AudioTestSource(wave: .silence)

    /// White noise source.
    public static let whiteNoise = AudioTestSource(wave: .whitenoise)

    /// A 440Hz sine wave (A4 note).
    public static let a440 = AudioTestSource(wave: .sine, frequency: 440)
}

/// A pipeline sink that plays audio through the system default output.
public struct AutoAudioSink: VideoPipelineElement {
    private let sync: Bool

    public var pipeline: String {
        var options = ["autoaudiosink"]
        if !sync {
            options.append("sync=false")
        }
        return options.joined(separator: " ")
    }

    /// Create an AutoAudioSink.
    ///
    /// - Parameter sync: Whether to synchronize to clock (default true).
    public init(sync: Bool = true) {
        self.sync = sync
    }
}

/// A pipeline element that applies audio level normalization.
public struct AudioAmplify: VideoPipelineElement {
    private let amplification: Double
    private let clipping: Bool

    public var pipeline: String {
        var options = ["audioamplify"]
        options.append("amplification=\(amplification)")
        if !clipping {
            options.append("clipping-method=none")
        }
        return options.joined(separator: " ")
    }

    /// Create an AudioAmplify element.
    ///
    /// - Parameters:
    ///   - amplification: Amplification factor (1.0 = no change, 2.0 = double).
    ///   - clipping: Whether to clip values that exceed range (default true).
    public init(amplification: Double, clipping: Bool = true) {
        self.amplification = amplification
        self.clipping = clipping
    }
}
