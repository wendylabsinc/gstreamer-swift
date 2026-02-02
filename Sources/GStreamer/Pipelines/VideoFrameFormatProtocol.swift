public protocol VideoFrameFormatProtocol: Sendable {
    static var name: String { get }
    static var options: [String] { get }
}
public enum RawVideoFrameFormat<
    PixelLayout: PixelLayoutProtocol
>: VideoFrameFormatProtocol {
    public static var name: String { "x-raw" }
    public static var options: [String] { 
        [
            "format=\(PixelLayout.name)",
        ]
    }
}