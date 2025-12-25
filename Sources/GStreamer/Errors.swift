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
/// - ``stateChangeFailed``
///
/// ### Bus and Buffer Errors
///
/// - ``busError(_:)``
/// - ``bufferMapFailed``
/// - ``capsParseFailed(_:)``
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
    /// ## Common Causes
    ///
    /// - Device not available (webcam in use)
    /// - File not found
    /// - Network unreachable
    /// - Invalid caps negotiation
    case stateChangeFailed

    /// An error message was received from the bus.
    ///
    /// This wraps errors that occur during pipeline execution.
    ///
    /// - Parameter message: The error message from GStreamer.
    case busError(String)

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
        case .stateChangeFailed:
            return "State change failed"
        case .busError(let message):
            return "Bus error: \(message)"
        case .bufferMapFailed:
            return "Failed to map buffer"
        case .capsParseFailed(let caps):
            return "Failed to parse caps: \(caps)"
        }
    }
}
