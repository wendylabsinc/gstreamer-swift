/// Text positioning on the video frame.
public enum TextPosition: Int, Sendable {
    case baseline = 0
    case bottom = 1
    case top = 2
    case positionCenter = 3
    case left = 4
    case right = 5
    case topLeft = 6
    case topRight = 7
    case bottomLeft = 8
    case bottomRight = 9
}

/// Horizontal alignment of text.
public enum TextHorizontalAlignment: String, Sendable {
    case left
    case center
    case right
}

/// A pipeline element that renders text on video frames.
///
/// In typed pipelines, the layout is automatically inferred from context.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func pipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
///     TypedVideoTestSource<BGRA<1920, 1080>>()
///     TextOverlay("Recording", position: .topLeft)  // Layout inferred automatically
/// }
/// ```
public struct TextOverlay: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let text: String?
    private let fontDescription: String?
    private let position: TextPosition?
    private let horizontalAlignment: TextHorizontalAlignment?
    private let color: UInt32?
    private let outlineColor: UInt32?
    private let shaded: Bool
    private let wrap: Bool
    private let deltaX: Int?
    private let deltaY: Int?

    public var pipeline: String {
        var options = ["textoverlay"]
        if let text {
            let escaped = escapeQuotes(text)
            options.append("text=\"\(escaped)\"")
        }
        if let fontDescription {
            options.append("font-desc=\"\(fontDescription)\"")
        }
        if let position {
            options.append("valignment=\(position.rawValue)")
        }
        if let horizontalAlignment {
            options.append("halignment=\(horizontalAlignment.rawValue)")
        }
        if let color {
            options.append("color=\(color)")
        }
        if let outlineColor {
            options.append("outline-color=\(outlineColor)")
        }
        if shaded {
            options.append("shaded-background=true")
        }
        if wrap {
            options.append("wrap-mode=word")
        }
        if let deltaX {
            options.append("deltax=\(deltaX)")
        }
        if let deltaY {
            options.append("deltay=\(deltaY)")
        }
        return options.joined(separator: " ")
    }

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    public init(
        _ text: String? = nil,
        font: String? = nil,
        position: TextPosition? = nil,
        horizontalAlignment: TextHorizontalAlignment? = nil,
        color: UInt32? = nil,
        outlineColor: UInt32? = nil,
        shaded: Bool = false,
        wrap: Bool = false,
        deltaX: Int? = nil,
        deltaY: Int? = nil
    ) {
        self.text = text
        self.fontDescription = font
        self.position = position
        self.horizontalAlignment = horizontalAlignment
        self.color = color
        self.outlineColor = outlineColor
        self.shaded = shaded
        self.wrap = wrap
        self.deltaX = deltaX
        self.deltaY = deltaY
    }
}

/// A pipeline element that renders the current time on video frames.
public struct ClockOverlay: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let position: TextPosition?
    private let fontDescription: String?
    private let shaded: Bool
    private let timeFormat: String?

    public var pipeline: String {
        var options = ["clockoverlay"]
        if let position {
            options.append("valignment=\(position.rawValue)")
        }
        if let fontDescription {
            options.append("font-desc=\"\(fontDescription)\"")
        }
        if shaded {
            options.append("shaded-background=true")
        }
        if let timeFormat {
            options.append("time-format=\"\(timeFormat)\"")
        }
        return options.joined(separator: " ")
    }

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    public init(
        position: TextPosition? = nil,
        font: String? = nil,
        shaded: Bool = false,
        timeFormat: String? = nil
    ) {
        self.position = position
        self.fontDescription = font
        self.shaded = shaded
        self.timeFormat = timeFormat
    }
}

/// What time to display.
public enum TimeMode: Int, Sendable {
    case bufferTime = 0
    case streamTime = 1
    case runningTime = 2
    case bufferCount = 3
}

/// A pipeline element that renders timestamps on video frames.
public struct TimeOverlay: TypedConvertible, VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let position: TextPosition?
    private let fontDescription: String?
    private let shaded: Bool
    private let timeMode: TimeMode?

    public var pipeline: String {
        var options = ["timeoverlay"]
        if let position {
            options.append("valignment=\(position.rawValue)")
        }
        if let fontDescription {
            options.append("font-desc=\"\(fontDescription)\"")
        }
        if shaded {
            options.append("shaded-background=true")
        }
        if let timeMode {
            options.append("time-mode=\(timeMode.rawValue)")
        }
        return options.joined(separator: " ")
    }

    public func _asTypedConvert<Layout: PixelLayoutProtocol>(_ layout: Layout.Type) -> AnyTypedConvert<Layout> {
        AnyTypedConvert<Layout>(pipeline: self.pipeline)
    }

    public init(
        position: TextPosition? = nil,
        font: String? = nil,
        shaded: Bool = false,
        timeMode: TimeMode? = nil
    ) {
        self.position = position
        self.fontDescription = font
        self.shaded = shaded
        self.timeMode = timeMode
    }
}

// MARK: - Helper

/// Replace double quotes with escaped quotes without Foundation dependency.
private func escapeQuotes(_ string: String) -> String {
    var result = ""
    for char in string {
        if char == "\"" {
            result.append("\\\"")
        } else {
            result.append(char)
        }
    }
    return result
}
