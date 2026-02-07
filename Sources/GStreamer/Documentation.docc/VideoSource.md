# VideoSource

Capture video from webcams with a high-level, cross-platform API.

## Overview

``VideoSource`` builds a pipeline for you and automatically selects the best
available backend on each platform. It supports common configuration such as
resolution, framerate, aspect-ratio handling, and optional encoding.

## Enumerating Cameras

```swift
let cameras = try VideoSource.availableWebcams()
for camera in cameras {
    print("[\(camera.index)] \(camera.name) \(camera.uniqueID)")
}
```

## Building a Webcam Source

```swift
let source = try VideoSource.webcam(deviceIndex: 0)
    .withResolution(.hd1080p)
    .withFramerate(30)
    .withAspectRatio(.sixteenByNine, cropIfNeeded: true)
    .build()

for try await frame in source.frames() {
    // Raw BGRA frames by default
    print("\(frame.width)x\(frame.height)")
}
```

## Encoded Output

```swift
let source = try VideoSource.webcam()
    .withResolution(.hd720p)
    .withJPEGEncoding(quality: 85)
    .preferHardwareAcceleration()
    .build()

for try await frame in source.frames() {
    // Encoded bytes are available via frame.bytes
}
```

## Multi-Camera Capture

```swift
let cam0 = try VideoSource.webcam(deviceIndex: 0).build()
let cam1 = try VideoSource.webcam(deviceIndex: 1).build()

await withTaskGroup(of: Void.self) { group in
    group.addTask {
        for try await frame in cam0.frames() {
            // Process camera 0
        }
    }
    group.addTask {
        for try await frame in cam1.frames() {
            // Process camera 1
        }
    }
}
```

## Test Pattern

```swift
let test = try VideoSource.testPattern()
    .withResolution(.hd720p)
    .build()

for try await frame in test.frames() {
    // Synthetic frames for testing
}
```
