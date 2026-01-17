/// Errors that can occur when working with GStreamer.
///
/// GStreamerError provides typed errors for all GStreamer operations.
/// Each case includes relevant context for debugging.
///
/// ## Overview
///
/// These errors are thrown by various GStreamer operations and should be
/// handled appropriately in your application.
///
/// ## Topics
///
/// ### Initialization Errors
///
/// - ``notInitialized``
/// - ``initializationFailed(_:)``
///
/// ### Pipeline Errors
///
/// - ``parsePipeline(_:)``
/// - ``elementNotFound(_:)``
/// - ``stateChangeFailed(element:from:to:)``
///
/// ### Bus and Buffer Errors
///
/// - ``busError(_:source:debug:)``
/// - ``bufferMapFailed``
/// - ``capsParseFailed(_:)``
///
/// ### Playback Errors
///
/// - ``seekFailed(position:)``
/// - ``pushFailed``
///
/// ## Example
///
/// ```swift
/// do {
///     try GStreamer.initialize()
///     let pipeline = try Pipeline("invalid ! pipeline")
/// } catch GStreamerError.notInitialized {
///     print("Call GStreamer.initialize() first")
/// } catch GStreamerError.parsePipeline(let message) {
///     print("Invalid pipeline: \(message)")
/// } catch GStreamerError.stateChangeFailed(let element, let from, let to) {
///     print("Failed to change \(element ?? "pipeline") from \(from) to \(to)")
/// } catch {
///     print("Unexpected error: \(error)")
/// }
/// ```
public enum GStreamerError: Error, Sendable, CustomStringConvertible {
    /// GStreamer has not been initialized.
    ///
    /// Call ``GStreamer/initialize(_:)`` before creating pipelines.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Wrong - will throw notInitialized
    /// let pipeline = try Pipeline("videotestsrc ! fakesink")
    ///
    /// // Correct
    /// try GStreamer.initialize()
    /// let pipeline = try Pipeline("videotestsrc ! fakesink")
    /// ```
    case notInitialized

    /// GStreamer initialization failed.
    ///
    /// This typically occurs when GStreamer libraries are not installed
    /// or cannot be loaded.
    ///
    /// - Parameter reason: Description of why initialization failed.
    case initializationFailed(String)

    /// Failed to parse pipeline description.
    ///
    /// The pipeline string contains invalid syntax or references
    /// unknown elements.
    ///
    /// - Parameter message: The parser error message.
    ///
    /// ## Common Causes
    ///
    /// - Unknown element name
    /// - Invalid property syntax
    /// - Missing required plugins
    ///
    /// ```swift
    /// // Unknown element
    /// try Pipeline("nonexistent ! fakesink")
    /// // throws: parsePipeline("no element \"nonexistent\"")
    ///
    /// // Invalid syntax
    /// try Pipeline("videotestsrc !!! fakesink")
    /// // throws: parsePipeline("syntax error")
    /// ```
    case parsePipeline(String)

    /// Element not found in pipeline.
    ///
    /// The requested element name doesn't exist in the pipeline.
    ///
    /// - Parameter name: The element name that wasn't found.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pipeline = try Pipeline("videotestsrc name=src ! fakesink")
    ///
    /// // This works
    /// let src = pipeline.element(named: "src")
    ///
    /// // This returns nil (doesn't throw)
    /// let missing = pipeline.element(named: "wrong")  // nil
    ///
    /// // AppSink throws if not found
    /// try AppSink(pipeline: pipeline, name: "wrong")
    /// // throws: elementNotFound("wrong")
    /// ```
    case elementNotFound(String)

    /// Failed to change element state.
    ///
    /// The pipeline or element couldn't transition to the requested state.
    /// This can occur due to resource constraints or invalid pipeline configuration.
    ///
    /// - Parameters:
    ///   - element: The name of the element that failed (nil for the pipeline itself).
    ///   - from: The state the element was in.
    ///   - to: The state that was requested.
    ///
    /// ## Common Causes
    ///
    /// - Device not available (webcam in use)
    /// - File not found
    /// - Network unreachable
    /// - Invalid caps negotiation
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try pipeline.play()
    /// } catch GStreamerError.stateChangeFailed(let element, let from, let to) {
    ///     if let element {
    ///         print("Element '\(element)' failed to change from \(from) to \(to)")
    ///     } else {
    ///         print("Pipeline failed to change from \(from) to \(to)")
    ///     }
    /// }
    /// ```
    case stateChangeFailed(element: String?, from: Pipeline.State, to: Pipeline.State)

    /// An error message was received from the bus.
    ///
    /// This wraps errors that occur during pipeline execution, with context
    /// about which element caused the error.
    ///
    /// - Parameters:
    ///   - message: The error message from GStreamer.
    ///   - source: The name of the element that caused the error, if available.
    ///   - debug: Debug information from GStreamer, if available.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try pipeline.play()
    ///     await pipeline.bus.waitForEOS()
    /// } catch GStreamerError.busError(let message, let source, let debug) {
    ///     print("Error from \(source ?? "unknown"): \(message)")
    ///     if let debug {
    ///         print("Debug: \(debug)")
    ///     }
    /// }
    /// ```
    case busError(_ message: String, source: String?, debug: String?)

    /// Failed to map buffer for reading.
    ///
    /// The buffer's memory couldn't be mapped into the process address space.
    /// This is rare and typically indicates a memory or driver issue.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try frame.withMappedBytes { span in
    ///     // If mapping fails, bufferMapFailed is thrown
    ///     // before the closure is called
    /// }
    /// ```
    case bufferMapFailed

    /// Failed to parse caps string.
    ///
    /// The capabilities string has invalid syntax.
    ///
    /// - Parameter caps: The invalid caps string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Valid caps
    /// let caps = try Caps("video/x-raw,format=BGRA,width=640,height=480")
    ///
    /// // Invalid caps
    /// try Caps("not a valid caps string")
    /// // throws: capsParseFailed("not a valid caps string")
    /// ```
    case capsParseFailed(String)

    /// Failed to seek to a position.
    ///
    /// The pipeline couldn't seek to the requested position. This can occur
    /// when seeking in non-seekable streams or when the position is invalid.
    ///
    /// - Parameter position: The requested seek position in nanoseconds.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try pipeline.seek(to: 10_000_000_000) // 10 seconds
    /// } catch GStreamerError.seekFailed(let position) {
    ///     print("Could not seek to \(position) ns")
    /// }
    /// ```
    case seekFailed(position: UInt64)

    /// Failed to push data to an appsrc element.
    ///
    /// This can occur when the pipeline is not in a state that accepts data,
    /// or when the appsrc's internal queue is full and set to block.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try appSource.push(data: frameData, pts: pts)
    /// } catch GStreamerError.pushFailed {
    ///     print("Pipeline not accepting data")
    /// }
    /// ```
    case pushFailed

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .notInitialized:
            return "GStreamer not initialized. Call GStreamer.initialize() first."
        case .initializationFailed(let reason):
            return "GStreamer initialization failed: \(reason)"
        case .parsePipeline(let message):
            return "Failed to parse pipeline: \(message)"
        case .elementNotFound(let name):
            return "Element not found: \(name)"
        case .stateChangeFailed(let element, let from, let to):
            if let element {
                return "State change failed: '\(element)' could not change from \(from) to \(to)"
            } else {
                return "State change failed: could not change from \(from) to \(to)"
            }
        case .busError(let message, let source, let debug):
            var result = "Bus error"
            if let source {
                result += " from '\(source)'"
            }
            result += ": \(message)"
            if let debug {
                result += "\n  Debug: \(debug)"
            }
            return result
        case .bufferMapFailed:
            return "Failed to map buffer"
        case .capsParseFailed(let caps):
            return "Failed to parse caps: \(caps)"
        case .seekFailed(let position):
            let seconds = Double(position) / 1_000_000_000.0
            let intPart = Int(seconds)
            let fracPart = Int((seconds - Double(intPart)) * 100)
            return "Failed to seek to \(intPart).\(fracPart < 10 ? "0" : "")\(fracPart)s"
        case .pushFailed:
            return "Failed to push data to appsrc"
        }
    }
}
