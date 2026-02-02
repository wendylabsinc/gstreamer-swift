/// A pipeline element that crops video frames by removing pixels from the edges.
///
/// ## Example
///
/// ```swift
/// @VideoPipelineBuilder
/// func croppedPipeline() -> PartialPipeline<VideoFrame> {
///     VideoTestSource()
///     VideoCrop(left: 100, right: 100, top: 50, bottom: 50)
/// }
/// ```
public struct VideoCrop: VideoPipelineConvert {
    public typealias VideoFrameInput = VideoFrame
    public typealias VideoFrameOutput = VideoFrame

    private let top: Int
    private let bottom: Int
    private let left: Int
    private let right: Int

    public var pipeline: String {
        var options = ["videocrop"]
        if top > 0 { options.append("top=\(top)") }
        if bottom > 0 { options.append("bottom=\(bottom)") }
        if left > 0 { options.append("left=\(left)") }
        if right > 0 { options.append("right=\(right)") }
        return options.joined(separator: " ")
    }

    /// Create a VideoCrop element with specified crop amounts.
    ///
    /// - Parameters:
    ///   - top: Pixels to crop from the top edge.
    ///   - bottom: Pixels to crop from the bottom edge.
    ///   - left: Pixels to crop from the left edge.
    ///   - right: Pixels to crop from the right edge.
    public init(top: Int = 0, bottom: Int = 0, left: Int = 0, right: Int = 0) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    /// Create a VideoCrop element with symmetric horizontal and vertical crop.
    ///
    /// - Parameters:
    ///   - horizontal: Pixels to crop from both left and right edges.
    ///   - vertical: Pixels to crop from both top and bottom edges.
    public init(horizontal: Int, vertical: Int) {
        self.top = vertical
        self.bottom = vertical
        self.left = horizontal
        self.right = horizontal
    }

    /// Create a VideoCrop element with uniform crop on all edges.
    ///
    /// - Parameter all: Pixels to crop from all edges.
    public init(all: Int) {
        self.top = all
        self.bottom = all
        self.left = all
        self.right = all
    }
}
