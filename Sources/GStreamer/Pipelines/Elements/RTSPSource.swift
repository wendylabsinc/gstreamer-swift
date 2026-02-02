/// RTSP source with low-latency settings, suitable for IP cameras.
public struct RTSPVideoSource: VideoPipelineSource {
    public typealias VideoFrameOutput = VideoFrame

    private let location: String
    private let latency: Int
    
    public var pipeline: String {
        "rtspsrc location=\(location) latency=\(latency)"
    }

    public init(location: String, latency: Int = 0) {
        self.location = location
        self.latency = latency
    }
}