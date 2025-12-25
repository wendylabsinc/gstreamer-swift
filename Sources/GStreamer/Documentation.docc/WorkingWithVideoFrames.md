# Working with Video Frames

Access and process raw video frame data safely with zero-copy memory access.

## Overview

GStreamer for Swift provides safe, zero-copy access to video frame data through the ``VideoFrame`` type. The ``VideoFrame/withMappedBytes(_:)`` method uses Swift's `RawSpan` to ensure memory safety while avoiding unnecessary copies.

## Accessing Pixel Data

### Basic Frame Access

Use `withMappedBytes` to access the raw pixel data:

```swift
for await frame in sink.frames() {
    try frame.withMappedBytes { span in
        span.withUnsafeBytes { buffer in
            // buffer is UnsafeRawBufferPointer
            print("Buffer size: \(buffer.count) bytes")
        }
    }
}
```

### Processing BGRA Pixels

For BGRA format (common on macOS/iOS), pixels are arranged as Blue, Green, Red, Alpha:

```swift
try frame.withMappedBytes { span in
    span.withUnsafeBytes { buffer in
        for i in stride(from: 0, to: buffer.count, by: 4) {
            let b = buffer[i]     // Blue
            let g = buffer[i + 1] // Green
            let r = buffer[i + 2] // Red
            let a = buffer[i + 3] // Alpha

            // Process pixel...
        }
    }
}
```

### Calculating Image Statistics

```swift
// Calculate average brightness
let brightness = try frame.withMappedBytes { span in
    span.withUnsafeBytes { buffer -> Int in
        var total = 0
        for i in stride(from: 0, to: buffer.count, by: 4) {
            // Weighted luminance: 0.299R + 0.587G + 0.114B
            total += Int(buffer[i + 2]) * 299 +
                     Int(buffer[i + 1]) * 587 +
                     Int(buffer[i]) * 114
        }
        return total / (buffer.count / 4) / 1000
    }
}
print("Average brightness: \(brightness)")
```

## Integration with Vision Framework

Create a `CVPixelBuffer` for use with Vision or CoreML:

```swift
import Vision
import CoreVideo

try frame.withMappedBytes { span in
    span.withUnsafeBytes { buffer in
        var pixelBuffer: CVPixelBuffer?

        CVPixelBufferCreateWithBytes(
            nil,
            frame.width,
            frame.height,
            kCVPixelFormatType_32BGRA,
            UnsafeMutableRawPointer(mutating: buffer.baseAddress!),
            frame.width * 4,  // bytes per row
            nil,
            nil,
            nil,
            &pixelBuffer
        )

        guard let pixelBuffer else { return }

        // Use with Vision
        let requestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            options: [:]
        )

        let request = VNDetectFaceRectanglesRequest()
        try? requestHandler.perform([request])

        if let results = request.results {
            print("Detected \(results.count) faces")
        }
    }
}
```

## Integration with Metal

Create a Metal texture from frame data:

```swift
import Metal

let device = MTLCreateSystemDefaultDevice()!

try frame.withMappedBytes { span in
    span.withUnsafeBytes { buffer in
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: frame.width,
            height: frame.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        let texture = device.makeTexture(descriptor: descriptor)!

        texture.replace(
            region: MTLRegionMake2D(0, 0, frame.width, frame.height),
            mipmapLevel: 0,
            withBytes: buffer.baseAddress!,
            bytesPerRow: frame.width * 4
        )

        // Use texture for rendering...
    }
}
```

## Memory Safety

The `RawSpan` returned by `withMappedBytes` cannot escape the closure. This ensures the underlying GStreamer buffer remains valid while you access it:

```swift
// CORRECT: Process data within the closure
try frame.withMappedBytes { span in
    span.withUnsafeBytes { buffer in
        processPixels(buffer)  // OK
    }
}

// The buffer is automatically unmapped here
```

If you need to keep the data, copy it within the closure:

```swift
let pixelData: [UInt8] = try frame.withMappedBytes { span in
    span.withUnsafeBytes { buffer in
        Array(buffer.bindMemory(to: UInt8.self))
    }
}

// pixelData is a copy, safe to use after the closure
```

## Handling Different Formats

Check the frame format before processing:

```swift
for await frame in sink.frames() {
    switch frame.format {
    case .bgra:
        // 4 bytes per pixel: BGRA
        try processBGRA(frame)

    case .rgba:
        // 4 bytes per pixel: RGBA
        try processRGBA(frame)

    case .nv12:
        // Y plane + UV plane (video decoder output)
        try processNV12(frame)

    case .gray8:
        // 1 byte per pixel (grayscale)
        try processGrayscale(frame)

    case .unknown(let format):
        print("Unknown format: \(format)")
    }
}
```

## Performance Tips

1. **Use the right format**: Request BGRA for Apple frameworks, NV12 for video codecs
2. **Avoid copies**: Process data directly in `withMappedBytes` when possible
3. **Batch processing**: Process multiple pixels per loop iteration
4. **Use SIMD**: Leverage Swift's SIMD types for parallel pixel operations

```swift
// Request specific format in pipeline
let pipeline = try Pipeline("""
    v4l2src ! videoconvert ! \
    video/x-raw,format=BGRA,width=1920,height=1080 ! \
    appsink name=sink
    """)
```
