/// A source that decodes any URI (file, http, rtsp, etc.) and outputs raw video.
/// Use this instead of `Playbin` when you need to chain elements after it (e.g., appsink).
public struct URIDecodeSource: VideoPipelineSource {
    public typealias VideoFrameOutput = VideoFrame

    private let uri: String
    public var pipeline: String {
        // videoscale allows scaling to target resolution
        // videoconvert allows format conversion
        "uridecodebin uri=\(uri)"
    }

    public init(uri: String) {
        self.uri = uri
    }

    public static func rtsp(_ url: String) -> Self {
        URIDecodeSource(uri: url)
    }

    public static func file(path: String) -> Self {
        URIDecodeSource(uri: "file://\(path)")
    }

    public static func http(url: String) -> Self {
        URIDecodeSource(uri: url.hasPrefix("http") ? url : "http://\(url)")
    }
}