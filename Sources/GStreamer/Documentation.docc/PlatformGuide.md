# Platform-Specific Pipelines

Configure GStreamer pipelines for different platforms and devices.

## Overview

GStreamer provides platform-specific elements for optimal performance on each system. This guide covers common configurations for Linux, NVIDIA Jetson, macOS, and more.

## Linux Webcam Capture

### USB Webcam with v4l2src

```swift
// Basic webcam capture
let pipeline = try Pipeline("""
    v4l2src device=/dev/video0 ! \
    videoconvert ! \
    video/x-raw,format=BGRA,width=640,height=480 ! \
    appsink name=sink
    """)

let sink = try pipeline.appSink(named: "sink")
try pipeline.play()

for await frame in sink.frames() {
    // Process webcam frames
    print("Frame: \(frame.width)x\(frame.height)")
}
```

### High-Resolution Capture

```swift
// 1080p webcam capture
let pipeline = try Pipeline("""
    v4l2src device=/dev/video0 ! \
    video/x-raw,width=1920,height=1080,framerate=30/1 ! \
    videoconvert ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

### Multiple Cameras

```swift
// Capture from specific camera by device path
let camera0 = try Pipeline("v4l2src device=/dev/video0 ! ...")
let camera1 = try Pipeline("v4l2src device=/dev/video2 ! ...")

// Or by bus location (more stable across reboots)
// Find with: v4l2-ctl --list-devices
```

## Linux Audio Capture

### ALSA Audio Source

```swift
// Capture audio from default ALSA device
let pipeline = try Pipeline("""
    alsasrc device=default ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=44100,channels=2 ! \
    appsink name=sink
    """)
```

### PulseAudio Source

```swift
// Capture from PulseAudio
let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=48000,channels=1 ! \
    appsink name=sink
    """)
```

## NVIDIA Jetson

### CSI Camera with nvarguscamerasrc

NVIDIA Jetson devices have hardware-accelerated camera capture:

```swift
// Jetson CSI camera (e.g., IMX219, IMX477)
let pipeline = try Pipeline("""
    nvarguscamerasrc sensor-id=0 ! \
    video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1 ! \
    nvvidconv ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)

let sink = try pipeline.appSink(named: "sink")
try pipeline.play()

for await frame in sink.frames() {
    // Process hardware-accelerated frames
    try frame.withMappedBytes { span in
        span.withUnsafeBytes { buffer in
            // Run inference on BGRA data
        }
    }
}
```

### USB Camera on Jetson

```swift
// USB camera with hardware conversion
let pipeline = try Pipeline("""
    v4l2src device=/dev/video0 ! \
    video/x-raw,width=1280,height=720 ! \
    nvvidconv ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

### Hardware Video Decode

```swift
// Decode H.264 video with hardware acceleration
let pipeline = try Pipeline("""
    filesrc location=video.mp4 ! \
    qtdemux ! h264parse ! \
    nvv4l2decoder ! \
    nvvidconv ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

### Camera Settings

```swift
// Adjust camera exposure and gain
let pipeline = try Pipeline("""
    nvarguscamerasrc \
        sensor-id=0 \
        exposuretimerange="13000 13000" \
        gainrange="1 1" \
        aelock=true ! \
    video/x-raw(memory:NVMM),width=1920,height=1080 ! \
    nvvidconv ! video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

## macOS

### AVFoundation Camera

```swift
// macOS webcam capture
let pipeline = try Pipeline("""
    avfvideosrc ! \
    videoconvert ! \
    video/x-raw,format=BGRA,width=1280,height=720 ! \
    appsink name=sink
    """)
```

### Screen Capture

```swift
// Capture screen on macOS
let pipeline = try Pipeline("""
    avfvideosrc capture-screen=true ! \
    videoconvert ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

## Network Streaming

### RTSP Client

```swift
// Receive RTSP stream from IP camera
let pipeline = try Pipeline("""
    rtspsrc location=rtsp://camera.local/stream latency=100 ! \
    rtph264depay ! h264parse ! \
    avdec_h264 ! \
    videoconvert ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

### UDP Stream Receiver

```swift
// Receive UDP video stream
let pipeline = try Pipeline("""
    udpsrc port=5000 ! \
    application/x-rtp,encoding-name=H264 ! \
    rtph264depay ! h264parse ! \
    avdec_h264 ! \
    videoconvert ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

## File Input/Output

### Read Video File

```swift
// Decode video file
let pipeline = try Pipeline("""
    filesrc location=/path/to/video.mp4 ! \
    decodebin ! \
    videoconvert ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

### Save to Video File

```swift
// Record webcam to file
let pipeline = try Pipeline("""
    v4l2src device=/dev/video0 ! \
    videoconvert ! \
    x264enc tune=zerolatency ! \
    mp4mux ! \
    filesink location=output.mp4
    """)
```

## Debugging Pipelines

### Enable Debug Output

Set environment variables before running:

```bash
export GST_DEBUG=3
export GST_DEBUG_FILE=gstreamer.log
```

### List Available Devices

```bash
# List video devices
v4l2-ctl --list-devices

# List GStreamer plugins
gst-inspect-1.0 | grep video

# Test pipeline before coding
gst-launch-1.0 v4l2src device=/dev/video0 ! autovideosink
```

### Check Element Properties

```bash
# See all properties of an element
gst-inspect-1.0 v4l2src
gst-inspect-1.0 nvarguscamerasrc
```
