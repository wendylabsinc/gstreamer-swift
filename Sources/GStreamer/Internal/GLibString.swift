import CGStreamer

/// Helper utilities for working with GLib strings.
internal enum GLibString {
    /// Convert a GLib string to a Swift String, freeing the GLib string.
    /// - Parameter gString: The GLib string (will be freed).
    /// - Returns: A Swift String, or nil if the input was nil.
    static func takeOwnership(_ gString: UnsafeMutablePointer<CChar>?) -> String? {
        guard let gString else { return nil }
        defer { g_free(gString) }
        return String(cString: gString)
    }

    /// Convert a GLib string to a Swift String without freeing it.
    /// - Parameter gString: The GLib string (will not be freed).
    /// - Returns: A Swift String, or nil if the input was nil.
    static func borrow(_ gString: UnsafePointer<CChar>?) -> String? {
        guard let gString else { return nil }
        return String(cString: gString)
    }
}

// MARK: - Foundation-free String Extensions

extension String {
    /// Trims leading and trailing ASCII whitespace (space, tab, newline, carriage return).
    /// This is a Foundation-free alternative to `trimmingCharacters(in: .whitespaces)`.
    internal func trimmingWhitespace() -> String {
        var start = startIndex
        var end = endIndex

        // Find first non-whitespace from start
        while start < end && self[start].isWhitespace {
            start = index(after: start)
        }

        // Find first non-whitespace from end
        while end > start {
            let prev = index(before: end)
            if !self[prev].isWhitespace {
                break
            }
            end = prev
        }

        return String(self[start..<end])
    }
}

extension Substring {
    /// Trims leading and trailing ASCII whitespace (space, tab, newline, carriage return).
    /// This is a Foundation-free alternative to `trimmingCharacters(in: .whitespaces)`.
    internal func trimmingWhitespace() -> Substring {
        var start = startIndex
        var end = endIndex

        // Find first non-whitespace from start
        while start < end && self[start].isWhitespace {
            start = index(after: start)
        }

        // Find first non-whitespace from end
        while end > start {
            let prev = index(before: end)
            if !self[prev].isWhitespace {
                break
            }
            end = prev
        }

        return self[start..<end]
    }
}
