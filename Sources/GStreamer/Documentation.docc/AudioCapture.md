# Audio Capture

Capture audio from microphones using ALSA, PipeWire, or PulseAudio.

## Overview

GStreamer supports multiple audio backends on Linux, allowing you to capture audio from microphones for speech recognition, voice assistants, audio processing, and more. This guide covers the three main audio systems:

- **ALSA** - Low-level Linux audio (always available)
- **PipeWire** - Modern audio/video server (Fedora, Ubuntu 22.10+)
- **PulseAudio** - Traditional Linux audio server

All three work identically with the ``AudioBufferSink`` and ``AudioBuffer`` APIs.

## Capturing Audio

### Basic Audio Capture

Use ``AudioBufferSink`` to receive audio buffers from a pipeline:

```swift
import GStreamer

try GStreamer.initialize()

let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
    appsink name=sink
    """)

let sink = try pipeline.audioBufferSink(named: "sink")
try pipeline.play()

for await buffer in sink.buffers() {
    print("Received \(buffer.sampleCount) samples")

    try buffer.withMappedBytes { span in
        span.withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Int16.self)
            // Process audio samples
        }
    }
}
```

### Audio Buffer Properties

Each ``AudioBuffer`` provides metadata about the audio:

```swift
for await buffer in sink.buffers() {
    print("Sample rate: \(buffer.sampleRate)Hz")
    print("Channels: \(buffer.channels)")
    print("Format: \(buffer.format)")
    print("Sample count: \(buffer.sampleCount)")

    if let pts = buffer.pts {
        print("Timestamp: \(Double(pts) / 1_000_000_000.0)s")
    }
}
```

## Audio Sources by Platform

### ALSA (All Linux)

ALSA (Advanced Linux Sound Architecture) is the low-level audio system available on all Linux distributions.

**Advantages:** Always available, lowest latency, direct hardware access.

**Use when:** You need direct device access or minimal latency.

```swift
// Default ALSA device
let pipeline = try Pipeline("""
    alsasrc device=default ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=44100,channels=2 ! \
    appsink name=sink
    """)

// Specific hardware device
let pipeline = try Pipeline("""
    alsasrc device=hw:0,0 ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=48000,channels=1 ! \
    appsink name=sink
    """)
```

List ALSA devices:
```bash
arecord -l
```

### PipeWire (Modern Linux)

PipeWire is the modern audio/video server, default on Fedora 34+, Ubuntu 22.10+, and many other distributions.

**Advantages:** Unified audio/video, better Bluetooth support, lower latency than PulseAudio, screen capture support.

**Use when:** On modern Linux distributions, especially for desktop applications.

Install the GStreamer plugin:
```bash
# Ubuntu/Debian
sudo apt install gstreamer1.0-pipewire

# Fedora
sudo dnf install gstreamer1-plugin-pipewire

# Arch
sudo pacman -S gst-plugin-pipewire
```

Capture audio:
```swift
let pipeline = try Pipeline("""
    pipewiresrc ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
    appsink name=sink
    """)
```

PipeWire also supports video capture (screen recording, cameras):
```swift
// Screen capture
let pipeline = try Pipeline("""
    pipewiresrc ! \
    videoconvert ! \
    video/x-raw,format=BGRA ! \
    appsink name=sink
    """)
```

### PulseAudio (Traditional Linux)

PulseAudio is the traditional Linux sound server, still used on many systems.

**Advantages:** Wide compatibility, good application mixing, per-application volume.

**Use when:** On older Linux distributions or when PipeWire isn't available.

Install the GStreamer plugin:
```bash
# Ubuntu/Debian
sudo apt install gstreamer1.0-pulseaudio

# Fedora (included in gst-plugins-good)
sudo dnf install gstreamer1-plugins-good

# Arch
sudo pacman -S gst-plugins-good
```

Capture audio:
```swift
let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
    appsink name=sink
    """)
```

Specify a device:
```swift
// List devices with: pactl list sources short
let pipeline = try Pipeline("""
    pulsesrc device=alsa_input.usb-Blue_Microphones-00 ! \
    audioconvert ! \
    audio/x-raw,format=S16LE,rate=48000,channels=1 ! \
    appsink name=sink
    """)
```

## Common Audio Formats

### Speech Recognition (16kHz mono)

Most speech recognition models expect 16kHz mono audio:

```swift
let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audioresample ! \
    audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
    appsink name=sink
    """)
```

### High-Quality Stereo (48kHz)

For music or high-fidelity audio:

```swift
let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audio/x-raw,format=S32LE,rate=48000,channels=2 ! \
    appsink name=sink
    """)
```

### Float Format (for DSP)

For digital signal processing:

```swift
let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audio/x-raw,format=F32LE,rate=44100,channels=1 ! \
    appsink name=sink
    """)

for await buffer in sink.buffers() {
    try buffer.withMappedBytes { span in
        span.withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Float.self)
            // DSP processing with float samples
        }
    }
}
```

## Playing Audio

### To PipeWire

```swift
let pipeline = try Pipeline("""
    appsrc name=src ! \
    audio/x-raw,format=S16LE,rate=44100,channels=2,layout=interleaved ! \
    audioconvert ! \
    pipewiresink
    """)

let src = try AppSource(pipeline: pipeline, name: "src")
src.setCaps("audio/x-raw,format=S16LE,rate=44100,channels=2,layout=interleaved")
try pipeline.play()

// Push audio samples
try src.push(data: audioSamples, pts: pts, duration: duration)
```

### To PulseAudio

```swift
let pipeline = try Pipeline("""
    appsrc name=src ! \
    audio/x-raw,format=S16LE,rate=44100,channels=2,layout=interleaved ! \
    audioconvert ! \
    pulsesink
    """)
```

### To ALSA

```swift
let pipeline = try Pipeline("""
    appsrc name=src ! \
    audio/x-raw,format=S16LE,rate=44100,channels=2,layout=interleaved ! \
    audioconvert ! \
    alsasink device=default
    """)
```

## Device Discovery

Use ``DeviceMonitor`` to find available audio devices:

```swift
let monitor = DeviceMonitor()

// List microphones
print("Microphones:")
for mic in monitor.audioSources() {
    print("  - \(mic.displayName)")
    if let api = mic.property("device.api") {
        print("    API: \(api)")  // alsa, pipewire, pulseaudio
    }
}

// List speakers
print("Speakers:")
for speaker in monitor.audioSinks() {
    print("  - \(speaker.displayName)")
}

// Create element from device
if let mic = monitor.audioSources().first,
   let source = mic.createElement(name: "mic") {
    // Use source in your pipeline
}
```

## Voice Assistant Example

A complete example for voice assistant input:

```swift
import GStreamer

try GStreamer.initialize()

// Capture audio for speech recognition
let pipeline = try Pipeline("""
    pulsesrc ! \
    audioconvert ! \
    audioresample ! \
    audio/x-raw,format=S16LE,rate=16000,channels=1 ! \
    appsink name=sink
    """)

let sink = try pipeline.audioBufferSink(named: "sink")
try pipeline.play()

// Collect audio in chunks for processing
var audioBuffer = [Int16]()
let chunkSize = 16000  // 1 second of audio

for await buffer in sink.buffers() {
    try buffer.withMappedBytes { span in
        span.withUnsafeBytes { bytes in
            let samples = Array(bytes.bindMemory(to: Int16.self))
            audioBuffer.append(contentsOf: samples)

            // Process when we have enough
            if audioBuffer.count >= chunkSize {
                let chunk = Array(audioBuffer.prefix(chunkSize))
                audioBuffer.removeFirst(chunkSize)

                // Send to speech recognition
                // speechRecognizer.process(chunk)
            }
        }
    }
}
```

## Topics

### Audio Types

- ``AudioBufferSink``
- ``AudioBuffer``
- ``AudioFormat``

### Related

- ``AppSource``
- ``DeviceMonitor``
- ``Device``
