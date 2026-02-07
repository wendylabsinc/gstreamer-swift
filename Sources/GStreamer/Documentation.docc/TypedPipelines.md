# Typed Pipelines

Build type-safe video pipelines with `@VideoPipelineBuilder` and typed layouts.

## Overview

The pipeline builder lets you compose GStreamer elements with Swift types that
encode pixel layouts and sizes at compile time. This gives you strong guarantees
about the frame format you receive, without parsing caps strings manually.

## Basic Typed Pipeline

```swift
@VideoPipelineBuilder
func pipeline() -> PartialPipeline<_VideoFrame<BGRA<640, 480>>> {
    VideoTestSource()
    VideoConvert()
    RawVideoFormat(layout: BGRA<640, 480>.self, framerate: "30/1")
}
```

This pipeline guarantees that the frames are BGRA 640x480 at 30 fps.

## Processing Frames with `withPipeline`

```swift
try await withPipeline {
    VideoTestSource(numberOfBuffers: 100)
    VideoConvert()
    RawVideoFormat(layout: BGRA<640, 480>.self, framerate: "30/1")
} withEachFrame: { frame in
    // frame is _VideoFrame<BGRA<640, 480>>
    let raw = frame.rawFrame
    print("\(raw.width)x\(raw.height) \(raw.format)")
}
```

## Mixing Typed and Untyped Elements

Typed elements preserve the layout type throughout the pipeline. If you insert
an untyped element, the type still remains consistent as long as the layout does
not change.

```swift
@VideoPipelineBuilder
func pipeline() -> PartialPipeline<_VideoFrame<BGRA<1920, 1080>>> {
    CameraSource()
    VideoConvert()
    TextOverlay("Hello")
    RawVideoFormat(layout: BGRA<1920, 1080>.self)
}
```

## When to Use Typed Pipelines

Use typed pipelines when you want compile-time safety for downstream processing
(e.g., ML inference, Metal textures, or image processing). For quick prototypes
or dynamic formats, the string-based `Pipeline` API remains a good fit.
