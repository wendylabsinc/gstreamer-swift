public struct VideoTestSource: VideoPipelineSource {
    public typealias VideoFrameOutput = VideoFrame

    public enum Pattern: String, Sendable {
        case smpte
        case snow
        case black
        case white
        case red
        case green
        case blue
        case checkers1 = "checkers-1"
        case checkers2 = "checkers-2"
        case checkers4 = "checkers-4"
        case checkers8 = "checkers-8"
        case circular
        case blink
        case smpte75
        case zonePlate = "zone-plate"
        case gamut
        case chromaZonePlate = "chroma-zone-plate"
        case solidColor = "solid-color"
        case ball
        case smpte100
        case branches
        case pinwheel
        case spokes
        case gradient
        case colors
        case smpteRP219 = "smpte-rp-219"
    }
    
    public let pipeline: String

    public init(pattern: Pattern = .snow, numberOfBuffers: Int? = nil, options additionalOptions: [String] = []) {
        var options = ["videotestsrc pattern=\(pattern.rawValue)"]
        if let numberOfBuffers {
            options.append("num-buffers=\(numberOfBuffers)")
        }
        options += additionalOptions
        self.pipeline = options.joined(separator: " ")
    }

    public static let snow = Self(pattern: .snow)
    public static let black = Self(pattern: .black)
    public static let white = Self(pattern: .white)
    public static let red = Self(pattern: .red)
    public static let green = Self(pattern: .green)
    public static let blue = Self(pattern: .blue)
    public static let checkers1 = Self(pattern: .checkers1)
    public static let checkers2 = Self(pattern: .checkers2)
    public static let checkers4 = Self(pattern: .checkers4)
    public static let checkers8 = Self(pattern: .checkers8)
    public static let circular = Self(pattern: .circular)
    public static let blink = Self(pattern: .blink)
    public static func solidColor(
        _ foregroundColor: String = "0xffffffff"
    ) async throws -> Self {
        Self(pattern: .solidColor, options: ["foreground-color=\(foregroundColor)"])
    }
}