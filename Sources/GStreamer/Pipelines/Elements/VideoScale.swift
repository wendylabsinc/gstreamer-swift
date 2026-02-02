public struct VideoScale: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    public var pipeline: String { "videoscale" }
    public init() {}
}