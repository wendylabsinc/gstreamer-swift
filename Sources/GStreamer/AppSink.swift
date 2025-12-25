import CGStreamer
import CGStreamerApp
import CGStreamerShim

/// A wrapper for GStreamer's appsink element for pulling video frames from a pipeline.
public final class AppSink: @unchecked Sendable {
    /// The underlying element.
    private let element: Element

    /// The GstAppSink pointer (cast from GstElement).
    private var appSink: UnsafeMutablePointer<GstAppSink> {
        UnsafeMutableRawPointer(element.element).assumingMemoryBound(to: GstAppSink.self)
    }

    /// Cached video info from caps.
    private var cachedWidth: Int = 0
    private var cachedHeight: Int = 0
    private var cachedFormat: PixelFormat = .unknown("")

    /// Create an AppSink from a pipeline by element name.
    /// - Parameters:
    ///   - pipeline: The pipeline containing the appsink.
    ///   - name: The name of the appsink element.
    /// - Throws: `GStreamerError.elementNotFound` if not found.
    public init(pipeline: Pipeline, name: String) throws {
        guard let element = pipeline.element(named: name) else {
            throw GStreamerError.elementNotFound(name)
        }
        self.element = element
    }

    /// Async stream of video frames. Internally polls the appsink.
    /// - Returns: An AsyncStream of VideoFrame values.
    public func frames() -> AsyncStream<VideoFrame> {
        AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                while !Task.isCancelled {
                    // Try to pull a sample with 100ms timeout
                    if let sample = swift_gst_app_sink_try_pull_sample(self.appSink, 100_000_000) {
                        defer { swift_gst_sample_unref(UnsafeMutableRawPointer(sample)) }

                        // Get buffer from sample
                        guard let buffer = swift_gst_sample_get_buffer(UnsafeMutableRawPointer(sample)) else {
                            continue
                        }

                        // Parse video info from caps - always try until we have valid values
                        if self.cachedWidth == 0 || self.cachedHeight == 0 {
                            if let caps = swift_gst_sample_get_caps(UnsafeMutableRawPointer(sample)) {
                                self.parseVideoInfo(from: caps)
                            }
                        }

                        // Get buffer size to validate
                        let bufferSize = swift_gst_buffer_get_size(buffer)
                        guard bufferSize > 0 else { continue }

                        // If we still don't have dimensions, try to infer from buffer size and format
                        var width = self.cachedWidth
                        var height = self.cachedHeight
                        let format = self.cachedFormat

                        if width == 0 || height == 0 {
                            // Try to infer dimensions from buffer size
                            let bytesPerPixel = format.bytesPerPixel
                            if bytesPerPixel > 0 {
                                let totalPixels = Int(bufferSize) / bytesPerPixel
                                // Common aspect ratios to try
                                let aspectRatios: [(Int, Int)] = [(16, 9), (4, 3), (1, 1)]
                                for (w, h) in aspectRatios {
                                    let testWidth = Int(sqrt(Double(totalPixels * w / h)))
                                    let testHeight = totalPixels / testWidth
                                    if testWidth * testHeight == totalPixels {
                                        width = testWidth
                                        height = testHeight
                                        // Cache for subsequent frames
                                        self.cachedWidth = width
                                        self.cachedHeight = height
                                        break
                                    }
                                }
                            }
                        }

                        // Ref the buffer so VideoFrame can own it
                        _ = swift_gst_buffer_ref(buffer)

                        let frame = VideoFrame(
                            buffer: buffer,
                            width: width,
                            height: height,
                            format: format,
                            ownsReference: true
                        )

                        continuation.yield(frame)
                    }

                    // Check for EOS
                    if swift_gst_app_sink_is_eos(self.appSink) != 0 {
                        break
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Parse video info from caps.
    private func parseVideoInfo(from caps: UnsafeMutablePointer<GstCaps>) {
        guard let capsString = swift_gst_caps_to_string(caps) else { return }
        defer { g_free(capsString) }

        let string = String(cString: capsString)
        let components = string.split(separator: ",")

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("width=") {
                // Handle both "width=320" and "width=(int)320"
                let value = extractValue(from: String(trimmed.dropFirst(6)))
                cachedWidth = Int(value) ?? 0
            } else if trimmed.hasPrefix("height=") {
                let value = extractValue(from: String(trimmed.dropFirst(7)))
                cachedHeight = Int(value) ?? 0
            } else if trimmed.hasPrefix("format=") {
                let value = extractValue(from: String(trimmed.dropFirst(7)))
                cachedFormat = PixelFormat(string: value)
            }
        }
    }

    /// Extract value from a GStreamer caps value that may have type annotation.
    /// Handles both "BGRA" and "(string)BGRA" and "(int)320".
    private func extractValue(from string: String) -> String {
        // Check for type annotation pattern like "(type)value"
        if let closeParenIndex = string.firstIndex(of: ")"),
           string.hasPrefix("(") {
            return String(string[string.index(after: closeParenIndex)...])
        }
        return string
    }
}
