public protocol PixelLayoutProtocol: Sendable {
    static var name: String { get }
    static var options: [String] { get }

    /// The layout type after a 90° or 270° rotation (width and height swapped).
    associatedtype Rotated: PixelLayoutProtocol
}

public enum RGBA<
    let width: Int,
    let height: Int
>: PixelLayoutProtocol {
    public static var name: String { "RGBA" }
    public static var options: [String] { [
        "width=\(width)",
        "height=\(height)",
    ] }
    public typealias Rotated = RGBA<height, width>
}

public enum BGRA<
    let width: Int,
    let height: Int
>: PixelLayoutProtocol {
    public static var name: String { "BGRA" }
    public static var options: [String] { [
        "width=\(width)",
        "height=\(height)",
    ] }
    public typealias Rotated = BGRA<height, width>
}

public enum NV12<
    let width: Int,
    let height: Int
>: PixelLayoutProtocol {
    public static var name: String { "NV12" }
    public static var options: [String] { [
        "width=\(width)",
        "height=\(height)",
    ] }
    public typealias Rotated = NV12<height, width>
}

public enum I420<
    let width: Int,
    let height: Int
>: PixelLayoutProtocol {
    public static var name: String { "I420" }
    public static var options: [String] { [
        "width=\(width)",
        "height=\(height)",
    ] }
    public typealias Rotated = I420<height, width>
}

public enum GRAY8<
    let width: Int,
    let height: Int
>: PixelLayoutProtocol {
    public static var name: String { "GRAY8" }
    public static var options: [String] { [
        "width=\(width)",
        "height=\(height)",
    ] }
    public typealias Rotated = GRAY8<height, width>
}