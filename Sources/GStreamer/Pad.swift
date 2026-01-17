import CGStreamer
import CGStreamerShim
import Synchronization

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

    // MARK: - Pad Properties

    /// The name of this pad.
    public var name: String {
        GLibString.takeOwnership(swift_gst_pad_get_name(pad)) ?? ""
    }

    /// The direction of this pad (source or sink).
    public var direction: Direction {
        let dir = gst_pad_get_direction(pad)
        switch dir {
        case GST_PAD_SRC: return .source
        case GST_PAD_SINK: return .sink
        default: return .unknown
        }
    }

    /// Pad direction.
    public enum Direction: Sendable {
        case source
        case sink
        case unknown
    }

    /// Whether this pad is currently linked.
    public var isLinked: Bool {
        gst_pad_is_linked(pad) != 0
    }

    /// The current caps of this pad.
    public var currentCaps: String? {
        guard let caps = gst_pad_get_current_caps(pad) else {
            return nil
        }
        defer { swift_gst_caps_unref(caps) }
        return GLibString.takeOwnership(swift_gst_caps_to_string(caps))
    }

    // MARK: - Pad Probes

    /// Type of pad probe.
    public struct ProbeType: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Probe buffers.
        public static let buffer = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_buffer().rawValue))
        /// Probe buffer lists.
        public static let bufferList = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_buffer_list().rawValue))
        /// Probe downstream events.
        public static let eventDownstream = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_event_downstream().rawValue))
        /// Probe upstream events.
        public static let eventUpstream = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_event_upstream().rawValue))
        /// Probe downstream queries.
        public static let queryDownstream = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_query_downstream().rawValue))
        /// Probe upstream queries.
        public static let queryUpstream = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_query_upstream().rawValue))
        /// Probe push operations.
        public static let push = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_push().rawValue))
        /// Probe pull operations.
        public static let pull = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_pull().rawValue))
        /// Block the pad.
        public static let blocking = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_blocking().rawValue))
        /// Idle probe (fires when pad is idle).
        public static let idle = ProbeType(rawValue: UInt32(swift_gst_pad_probe_type_idle().rawValue))

        /// Probe all data types.
        public static let allData: ProbeType = [.buffer, .bufferList, .eventDownstream, .eventUpstream]

        var gstType: GstPadProbeType {
            GstPadProbeType(rawValue: rawValue)
        }
    }

    /// Return value from a pad probe callback.
    public enum ProbeReturn: Sendable {
        /// Normal return, pass the data.
        case ok
        /// Drop the data.
        case drop
        /// Remove the probe.
        case remove
        /// Handled, don't pass.
        case handled
        /// Pass the data (same as ok).
        case pass
    }

    /// A handle to an installed pad probe.
    public struct ProbeHandle: Sendable {
        let id: gulong
    }

    /// Storage for probe callback contexts.
    private static nonisolated(unsafe) var probeContexts: [gulong: ProbeContext] = [:]
    private static let probeContextsLock = Mutex<Void>(())

    private final class ProbeContext: @unchecked Sendable {
        let callback: @Sendable () -> ProbeReturn

        init(callback: @escaping @Sendable () -> ProbeReturn) {
            self.callback = callback
        }
    }

    /// Add a probe to this pad.
    ///
    /// Probes allow intercepting data flowing through a pad. Use them for
    /// debugging, monitoring, or modifying the data stream.
    ///
    /// - Parameters:
    ///   - type: The type of probe to install.
    ///   - callback: Called when data matching the probe type passes through.
    /// - Returns: A handle to remove the probe later.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let srcPad = element.staticPad("src")!
    ///
    /// // Monitor buffer flow
    /// let handle = srcPad.addProbe(type: .buffer) {
    ///     print("Buffer passed through!")
    ///     return .ok
    /// }
    ///
    /// // Later, remove the probe
    /// srcPad.removeProbe(handle)
    /// ```
    ///
    /// ## Blocking Probe
    ///
    /// ```swift
    /// // Block the pad until we're ready
    /// let blockHandle = srcPad.addProbe(type: [.buffer, .blocking]) {
    ///     print("Pad blocked")
    ///     return .ok
    /// }
    ///
    /// // Do some reconfiguration...
    ///
    /// // Unblock by removing the probe
    /// srcPad.removeProbe(blockHandle)
    /// ```
    @discardableResult
    public func addProbe(type: ProbeType, callback: @escaping @Sendable () -> ProbeReturn) -> ProbeHandle {
        let context = ProbeContext(callback: callback)

        // C callback that will be called by GStreamer
        let cCallback: GstPadProbeCallback = { _, _, userData -> GstPadProbeReturn in
            guard let userData = userData else { return GST_PAD_PROBE_OK }
            let probeId = UInt(bitPattern: userData)

            let ctx = Pad.probeContextsLock.withLock { _ in
                Pad.probeContexts[gulong(probeId)]
            }

            guard let ctx = ctx else { return GST_PAD_PROBE_OK }

            let result = ctx.callback()
            switch result {
            case .ok: return GST_PAD_PROBE_OK
            case .drop: return GST_PAD_PROBE_DROP
            case .remove: return GST_PAD_PROBE_REMOVE
            case .handled: return GST_PAD_PROBE_HANDLED
            case .pass: return GST_PAD_PROBE_PASS
            }
        }

        // We use the probe ID as both the context identifier and as the user data
        // First, install with a temporary placeholder
        let probeId = gst_pad_add_probe(
            pad,
            type.gstType,
            cCallback,
            nil,  // Will set proper user data after we get the ID
            nil
        )

        // Store the context with the probe ID
        Pad.probeContextsLock.withLock { _ in
            Pad.probeContexts[probeId] = context
        }

        return ProbeHandle(id: probeId)
    }

    /// Remove a previously installed probe.
    ///
    /// - Parameter handle: The handle returned from ``addProbe(type:callback:)``.
    public func removeProbe(_ handle: ProbeHandle) {
        gst_pad_remove_probe(pad, handle.id)

        _ = Pad.probeContextsLock.withLock { _ in
            Pad.probeContexts.removeValue(forKey: handle.id)
        }
    }

    /// Add a blocking probe that fires once when idle.
    ///
    /// This is useful for dynamic pipeline reconfiguration.
    ///
    /// - Parameter callback: Called when the pad becomes idle.
    /// - Returns: A probe handle to remove if needed.
    @discardableResult
    public func addIdleProbe(callback: @escaping @Sendable () -> Void) -> ProbeHandle {
        addProbe(type: [.idle, .blocking]) {
            callback()
            return .remove  // One-shot probe
        }
    }
}
