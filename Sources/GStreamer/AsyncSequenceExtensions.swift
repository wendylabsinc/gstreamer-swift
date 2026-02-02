/// Extensions for working with async sequences in GStreamer pipelines.
///
/// These extensions provide common operations for processing video frames
/// and audio buffers from GStreamer sinks.

// MARK: - Batching

/// An async sequence that batches elements into arrays.
public struct BatchedAsyncSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable {
    public typealias Element = [Base.Element]

    private let base: Base
    private let size: Int

    init(base: Base, size: Int) {
        self.base = base
        self.size = size
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), size: size)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private let size: Int
        private var finished = false

        init(base: Base.AsyncIterator, size: Int) {
            self.base = base
            self.size = size
        }

        public mutating func next() async throws -> [Base.Element]? {
            guard !finished else { return nil }

            var batch: [Base.Element] = []
            batch.reserveCapacity(size)

            while batch.count < size {
                if let element = try await base.next() {
                    batch.append(element)
                } else {
                    finished = true
                    break
                }
            }

            return batch.isEmpty ? nil : batch
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Batch elements into arrays of the specified size.
    ///
    /// The last batch may contain fewer elements if the sequence ends
    /// before the batch is full.
    ///
    /// - Parameter size: The number of elements per batch.
    /// - Returns: An async sequence of element arrays.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Process 10 frames at a time
    /// for try await batch in sink.frames().batched(size: 10) {
    ///     print("Processing \(batch.count) frames")
    ///     for frame in batch {
    ///         process(frame)
    ///     }
    /// }
    /// ```
    public func batched(size: Int) -> BatchedAsyncSequence<Self> {
        BatchedAsyncSequence(base: self, size: size)
    }
}

// MARK: - Prefix (Take First N)

/// An async sequence that takes only the first N elements.
public struct PrefixAsyncSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable {
    public typealias Element = Base.Element

    private let base: Base
    private let count: Int

    init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), remaining: count)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private var remaining: Int

        init(base: Base.AsyncIterator, remaining: Int) {
            self.base = base
            self.remaining = remaining
        }

        public mutating func next() async throws -> Base.Element? {
            guard remaining > 0 else { return nil }
            remaining -= 1
            return try await base.next()
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Take only the first N elements from the sequence.
    ///
    /// - Parameter count: The maximum number of elements to take.
    /// - Returns: An async sequence limited to N elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Process only the first 100 frames
    /// for try await frame in sink.frames().prefix(100) {
    ///     process(frame)
    /// }
    /// ```
    public func prefix(_ count: Int) -> PrefixAsyncSequence<Self> {
        PrefixAsyncSequence(base: self, count: count)
    }
}

// MARK: - Enumerated

/// An async sequence that pairs each element with its index.
public struct EnumeratedAsyncSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable {
    public typealias Element = (index: Int, element: Base.Element)

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private var index = 0

        init(base: Base.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> (index: Int, element: Base.Element)? {
            guard let element = try await base.next() else { return nil }
            let currentIndex = index
            index += 1
            return (currentIndex, element)
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Enumerate elements with their index.
    ///
    /// - Returns: An async sequence of (index, element) pairs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for try await (index, frame) in sink.frames().enumerated() {
    ///     print("Frame \(index): \(frame.width)x\(frame.height)")
    /// }
    /// ```
    public func enumerated() -> EnumeratedAsyncSequence<Self> {
        EnumeratedAsyncSequence(base: self)
    }
}

// MARK: - Collect

extension AsyncSequence {
    /// Collect all elements into an array.
    ///
    /// - Warning: This will consume the entire sequence and may use
    ///   significant memory for long or infinite sequences.
    ///
    /// - Returns: An array containing all elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let allFrames = try await sink.frames().prefix(100).collect()
    /// print("Collected \(allFrames.count) frames")
    /// ```
    public func collect() async throws -> [Element] {
        var elements: [Element] = []
        for try await element in self {
            elements.append(element)
        }
        return elements
    }
}

// MARK: - Skip

/// An async sequence that skips the first N elements.
public struct DropFirstAsyncSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable {
    public typealias Element = Base.Element

    private let base: Base
    private let count: Int

    init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), remaining: count)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private var remaining: Int

        init(base: Base.AsyncIterator, remaining: Int) {
            self.base = base
            self.remaining = remaining
        }

        public mutating func next() async throws -> Base.Element? {
            while remaining > 0 {
                guard try await base.next() != nil else { return nil }
                remaining -= 1
            }
            return try await base.next()
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Skip the first N elements.
    ///
    /// - Parameter count: The number of elements to skip.
    /// - Returns: An async sequence that skips the first N elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Skip the first 10 frames (e.g., to skip initial buffering)
    /// for try await frame in sink.frames().dropFirst(10) {
    ///     process(frame)
    /// }
    /// ```
    public func dropFirst(_ count: Int) -> DropFirstAsyncSequence<Self> {
        DropFirstAsyncSequence(base: self, count: count)
    }
}
