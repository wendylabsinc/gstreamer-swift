# ``GStreamer``

A modern Swift wrapper for GStreamer with async/await support.

## Overview

GStreamer for Swift provides a type-safe, Swift-native interface to the GStreamer multimedia framework. Build powerful video processing pipelines with Swift Concurrency.

```swift
import GStreamer

try GStreamer.initialize()

// Create a pipeline that captures from webcam
let pipeline = try Pipeline("""
    v4l2src device=/dev/video0 ! \
    videoconvert ! \
    video/x-raw,format=BGRA,width=640,height=480 ! \
    appsink name=sink
    """)

let sink = try pipeline.appSink(named: "sink")
try pipeline.play()

// Process frames with async/await
for await frame in sink.frames() {
    try frame.withMappedBytes { span in
        span.withUnsafeBytes { buffer in
            // Process raw BGRA pixels
        }
    }
}
```

## Featured

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:WorkingWithVideoFrames>
    - <doc:PlatformGuide>
}

## Topics

### Essentials

- <doc:GettingStarted>
- ``GStreamer``
- ``Pipeline``

### Video Processing

- <doc:WorkingWithVideoFrames>
- ``AppSink``
- ``VideoFrame``
- ``PixelFormat``

### Pipeline Components

- ``Element``
- ``Caps``
- ``Bus``
- ``BusMessage``

### Error Handling

- ``GStreamerError``

### Platform Guides

- <doc:PlatformGuide>
