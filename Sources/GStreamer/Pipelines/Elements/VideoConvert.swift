public struct VideoConvert: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    public var pipeline: String { "videoconvert" }
    public init() {}
}