#if canImport(CoreVideo)
public import CoreVideo
import CGStreamer
import CGStreamerShim

extension VideoFrame {
    /// Create a CVPixelBuffer from this video frame.
    ///
    /// This method creates a CVPixelBuffer suitable for use with Vision framework,
    /// CoreML, Metal, and other Apple APIs. The pixel data is copied into the
    /// CVPixelBuffer.
    ///
    /// - Returns: A CVPixelBuffer, or `nil` if creation failed.
    /// - Throws: ``GStreamerError/bufferMapFailed`` if the frame cannot be mapped.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await frame in sink.frames() {
    ///     if let pixelBuffer = try frame.toCVPixelBuffer() {
    ///         // Use with Vision
    ///         let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
    ///         try handler.perform([detectRequest])
    ///     }
    /// }
    /// ```
    ///
    /// ## CoreML Integration
    ///
    /// ```swift
    /// let model = try MyMLModel()
    ///
    /// for await frame in sink.frames() {
    ///     if let pixelBuffer = try frame.toCVPixelBuffer() {
    ///         let prediction = try model.prediction(image: pixelBuffer)
    ///         print("Detected: \(prediction.classLabel)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Vision Framework Example
    ///
    /// ```swift
    /// let faceDetection = VNDetectFaceRectanglesRequest()
    ///
    /// for await frame in sink.frames() {
    ///     guard let pixelBuffer = try frame.toCVPixelBuffer() else { continue }
    ///
    ///     let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
    ///     try handler.perform([faceDetection])
    ///
    ///     if let results = faceDetection.results {
    ///         for face in results {
    ///             print("Face at: \(face.boundingBox)")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## Supported Formats
    ///
    /// The following pixel formats are supported:
    /// - `.bgra` → `kCVPixelFormatType_32BGRA`
    /// - `.rgba` → `kCVPixelFormatType_32RGBA`
    /// - `.nv12` → `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`
    /// - `.i420` → `kCVPixelFormatType_420YpCbCr8Planar`
    /// - `.gray8` → `kCVPixelFormatType_OneComponent8`
    ///
    /// Other formats will return `nil`.
    public func toCVPixelBuffer() throws -> CVPixelBuffer? {
        guard let cvFormat = format.cvPixelFormat else {
            return nil
        }

        var pixelBuffer: CVPixelBuffer?

        let attrs: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            cvFormat,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])

        // Access pixel data for reading
        try withUnsafeBytes { srcBuffer in
            // Handle planar vs packed formats
            if CVPixelBufferIsPlanar(buffer) {
                copyPlanarData(from: srcBuffer, to: buffer)
            } else {
                copyPackedData(from: srcBuffer, to: buffer)
            }
        }

        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    /// Copy packed pixel data to CVPixelBuffer.
    private func copyPackedData(from src: UnsafeRawBufferPointer, to buffer: CVPixelBuffer) {
        guard let destBase = CVPixelBufferGetBaseAddress(buffer),
              let srcBase = src.baseAddress else { return }

        let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let srcBytesPerRow = width * format.bytesPerPixel

        // Copy row by row to handle stride differences
        for y in 0..<height {
            let srcRow = srcBase.advanced(by: y * srcBytesPerRow)
            let destRow = destBase.advanced(by: y * destBytesPerRow)
            memcpy(destRow, srcRow, srcBytesPerRow)
        }
    }

    /// Copy planar pixel data to CVPixelBuffer (for NV12, I420, etc.).
    private func copyPlanarData(from src: UnsafeRawBufferPointer, to buffer: CVPixelBuffer) {
        let planeCount = CVPixelBufferGetPlaneCount(buffer)

        switch format {
        case .nv12:
            // NV12: Y plane + interleaved UV plane
            copyNV12(from: src, to: buffer)
        case .i420:
            // I420: Y plane + U plane + V plane
            copyI420(from: src, to: buffer)
        default:
            // For other planar formats, copy plane by plane
            guard let srcBase = src.baseAddress else { return }
            var srcOffset = 0
            for plane in 0..<planeCount {
                guard let destBase = CVPixelBufferGetBaseAddressOfPlane(buffer, plane) else { continue }
                let planeHeight = CVPixelBufferGetHeightOfPlane(buffer, plane)
                let planeBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
                let planeBytes = planeHeight * planeBytesPerRow

                let srcPlane = srcBase.advanced(by: srcOffset)
                memcpy(destBase, srcPlane, planeBytes)
                srcOffset += planeBytes
            }
        }
    }

    /// Copy NV12 data to CVPixelBuffer.
    private func copyNV12(from src: UnsafeRawBufferPointer, to buffer: CVPixelBuffer) {
        guard let srcBase = src.baseAddress else { return }

        // Y plane
        if let yDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) {
            let yHeight = CVPixelBufferGetHeightOfPlane(buffer, 0)
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            let srcYBytesPerRow = width

            for y in 0..<yHeight {
                let srcRow = srcBase.advanced(by: y * srcYBytesPerRow)
                let destRow = yDest.advanced(by: y * yBytesPerRow)
                memcpy(destRow, srcRow, srcYBytesPerRow)
            }
        }

        // UV plane
        if let uvDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) {
            let uvHeight = CVPixelBufferGetHeightOfPlane(buffer, 1)
            let uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            let srcUVBytesPerRow = width
            let yPlaneSize = width * height

            for y in 0..<uvHeight {
                let srcRow = srcBase.advanced(by: yPlaneSize + y * srcUVBytesPerRow)
                let destRow = uvDest.advanced(by: y * uvBytesPerRow)
                memcpy(destRow, srcRow, srcUVBytesPerRow)
            }
        }
    }

    /// Copy I420 data to CVPixelBuffer.
    private func copyI420(from src: UnsafeRawBufferPointer, to buffer: CVPixelBuffer) {
        guard let srcBase = src.baseAddress else { return }

        let ySize = width * height
        let uvWidth = width / 2
        let uvHeight = height / 2
        let uvSize = uvWidth * uvHeight

        // Y plane
        if let yDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) {
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            for y in 0..<height {
                let srcRow = srcBase.advanced(by: y * width)
                let destRow = yDest.advanced(by: y * yBytesPerRow)
                memcpy(destRow, srcRow, width)
            }
        }

        // U plane (Cb)
        if let uDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) {
            let uBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            for y in 0..<uvHeight {
                let srcRow = srcBase.advanced(by: ySize + y * uvWidth)
                let destRow = uDest.advanced(by: y * uBytesPerRow)
                memcpy(destRow, srcRow, uvWidth)
            }
        }

        // V plane (Cr)
        if let vDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 2) {
            let vBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 2)
            for y in 0..<uvHeight {
                let srcRow = srcBase.advanced(by: ySize + uvSize + y * uvWidth)
                let destRow = vDest.advanced(by: y * vBytesPerRow)
                memcpy(destRow, srcRow, uvWidth)
            }
        }
    }
}

extension PixelFormat {
    /// Convert to CoreVideo pixel format type.
    ///
    /// Returns `nil` for formats not supported by CoreVideo.
    public var cvPixelFormat: OSType? {
        switch self {
        case .bgra:
            return kCVPixelFormatType_32BGRA
        case .rgba:
            return kCVPixelFormatType_32RGBA
        case .nv12:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case .i420:
            return kCVPixelFormatType_420YpCbCr8Planar
        case .gray8:
            return kCVPixelFormatType_OneComponent8
        default:
            return nil
        }
    }
}
#endif
