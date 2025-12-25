import CGStreamer
import CGStreamerShim

/// A GStreamer pad for connecting elements.
///
/// Pads are the connection points between elements. Data flows from source pads
/// to sink pads. Use pads for dynamic pipeline construction and tee splitting.
///
/// ## Overview
///
/// Pads come in two types:
/// - Static pads: Always present on an element (e.g., "sink", "src")
/// - Request pads: Created on demand (e.g., "src_%u" on tee)
///
/// ## Topics
///
/// ### Linking
///
/// - ``link(to:)``
/// - ``unlink(from:)``
///
/// ## Example
///
/// ```swift
/// // Get static pads
/// let srcPad = source.staticPad("src")!
/// let sinkPad = sink.staticPad("sink")!
///
/// // Link them
/// srcPad.link(to: sinkPad)
/// ```
///
/// ## Tee Example
///
/// ```swift
/// // Create a tee to split a stream
/// let tee = try Element.make(factory: "tee", name: "splitter")
/// pipeline.add(tee)
///
/// // Request pads for each branch
/// let branch1Pad = tee.requestPad("src_%u")!
/// let branch2Pad = tee.requestPad("src_%u")!
///
/// // Link to downstream elements
/// branch1Pad.link(to: queue1.staticPad("sink")!)
/// branch2Pad.link(to: queue2.staticPad("sink")!)
/// ```
public final class Pad: @unchecked Sendable {
    /// The underlying GstPad pointer.
    internal let pad: UnsafeMutablePointer<GstPad>

    /// Whether this is a request pad that needs to be released.
    private let isRequestPad: Bool

    /// The element that owns this pad (for request pads).
    private weak var ownerElement: Element?

    internal init(pad: UnsafeMutablePointer<GstPad>, isRequestPad: Bool = false, element: Element? = nil) {
        self.pad = pad
        self.isRequestPad = isRequestPad
        self.ownerElement = element
    }

    deinit {
        swift_gst_pad_unref(pad)
    }

    /// Link this pad to another pad.
    ///
    /// - Parameter other: The sink pad to link to.
    /// - Returns: `true` if linking succeeded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let success = srcPad.link(to: sinkPad)
    /// if !success {
    ///     print("Failed to link pads")
    /// }
    /// ```
    @discardableResult
    public func link(to other: Pad) -> Bool {
        swift_gst_pad_link(pad, other.pad) != 0
    }

    /// Unlink this pad from another pad.
    ///
    /// - Parameter other: The pad to unlink from.
    /// - Returns: `true` if unlinking succeeded.
    @discardableResult
    public func unlink(from other: Pad) -> Bool {
        swift_gst_pad_unlink(pad, other.pad) != 0
    }
}
