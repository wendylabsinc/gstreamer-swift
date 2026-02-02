#if os(macOS)
public struct OSXVideoSink: VideoSink {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = Never
    public var pipeline: String {
        "osxvideosink"
    }
    public init() {}
}
#endif