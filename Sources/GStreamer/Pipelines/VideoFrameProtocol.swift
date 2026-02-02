public protocol VideoFrameProtocol: Sendable {
    init(unsafeCast: VideoFrame)
}
extension VideoFrame: VideoFrameProtocol {
    public init(unsafeCast: VideoFrame) {
        self = unsafeCast
    }
}
public struct _VideoFrame<
    PixelLayout: PixelLayoutProtocol
>: VideoFrameProtocol {
    public let rawFrame: VideoFrame

    public init(unsafeCast: VideoFrame) {
        self.rawFrame = unsafeCast
    }
}