/// A pipeline element that adjusts video color properties.
///
/// VideoBalance allows real-time adjustment of brightness, contrast,
/// hue, and saturation. It preserves the frame layout type in typed pipelines automatically.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func adjustedPipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     TypedVideoTestSource<BGRA<1920, 1080>>()
///     VideoBalance(brightness: 0.2, contrast: 1.5)  // Layout inferred
/// }
/// ```
public struct VideoBalance: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    private let brightness: Double?
    private let contrast: Double?
    private let hue: Double?
    private let saturation: Double?

    public var pipeline: String {
        var options = ["videobalance"]
        if let brightness {
            options.append("brightness=\(brightness)")
        }
        if let contrast {
            options.append("contrast=\(contrast)")
        }
        if let hue {
            options.append("hue=\(hue)")
        }
        if let saturation {
            options.append("saturation=\(saturation)")
        }
        return options.joined(separator: " ")
    }

    /// Create a VideoBalance element with specified adjustments.
    ///
    /// - Parameters:
    ///   - brightness: Brightness adjustment (-1.0 to 1.0, default 0.0)
    ///   - contrast: Contrast adjustment (0.0 to 2.0, default 1.0)
    ///   - hue: Hue rotation (-1.0 to 1.0, default 0.0)
    ///   - saturation: Saturation adjustment (0.0 to 2.0, default 1.0)
    public init(
        brightness: Double? = nil,
        contrast: Double? = nil,
        hue: Double? = nil,
        saturation: Double? = nil
    ) {
        self.brightness = brightness
        self.contrast = contrast
        self.hue = hue
        self.saturation = saturation
    }

    /// Increase brightness.
    public static func bright(_ amount: Double = 0.3) -> VideoBalance {
        VideoBalance(brightness: amount)
    }

    /// Convert to grayscale by removing saturation.
    public static let grayscale = VideoBalance(saturation: 0.0)

    /// High contrast preset.
    public static let highContrast = VideoBalance(contrast: 1.5)
}
