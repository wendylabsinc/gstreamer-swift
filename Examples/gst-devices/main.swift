import GStreamer

/// Example showing device discovery with DeviceMonitor.
///
/// Lists all available video and audio devices, including:
/// - Cameras (webcams, CSI cameras on Jetson)
/// - Microphones
/// - Speakers/audio outputs
@main
struct GstDevicesExample {
    static func main() async throws {
        print("GStreamer version: \(GStreamer.versionString)")
        print(String(repeating: "=", count: 60))

        let monitor = DeviceMonitor()

        // List all devices
        let allDevices = monitor.allDevices()
        print("\nFound \(allDevices.count) device(s)\n")

        // Video Sources (Cameras)
        print("CAMERAS")
        print(String(repeating: "-", count: 60))
        let cameras = monitor.videoSources()
        if cameras.isEmpty {
            print("  No cameras found")
        } else {
            for (index, camera) in cameras.enumerated() {
                printDevice(camera, index: index)
            }
        }

        // Audio Sources (Microphones)
        print("\nMICROPHONES")
        print(String(repeating: "-", count: 60))
        let microphones = monitor.audioSources()
        if microphones.isEmpty {
            print("  No microphones found")
        } else {
            for (index, mic) in microphones.enumerated() {
                printDevice(mic, index: index)
            }
        }

        // Audio Sinks (Speakers)
        print("\nSPEAKERS")
        print(String(repeating: "-", count: 60))
        let speakers = monitor.audioSinks()
        if speakers.isEmpty {
            print("  No speakers found")
        } else {
            for (index, speaker) in speakers.enumerated() {
                printDevice(speaker, index: index)
            }
        }

        // Example: Create a pipeline element from a device
        print("\n" + String(repeating: "=", count: 60))
        print("EXAMPLE: Creating pipeline element from device")
        print(String(repeating: "-", count: 60))

        if let firstMic = microphones.first {
            print("Using microphone: \(firstMic.displayName)")

            if let element = firstMic.createElement(name: "mic_source") {
                print("Created element: \(element.name)")
                print("\nExample usage:")
                print("  let source = device.createElement(name: \"mic\")")
                print("  pipeline.add(source)")
                print("  source.link(to: nextElement)")
            }
        } else if let firstCamera = cameras.first {
            print("Using camera: \(firstCamera.displayName)")

            if let element = firstCamera.createElement(name: "cam_source") {
                print("Created element: \(element.name)")
                print("\nExample usage:")
                print("  let source = device.createElement(name: \"cam\")")
                print("  pipeline.add(source)")
                print("  source.link(to: nextElement)")
            }
        } else {
            print("No devices available to create element from")
        }
    }

    static func printDevice(_ device: Device, index: Int) {
        print("  [\(index)] \(device.displayName)")

        let deviceClass = device.deviceClass
        if !deviceClass.isEmpty {
            print("      Class: \(deviceClass)")
        }

        // Show API (alsa, pulseaudio, pipewire, v4l2, etc.)
        if let api = device.property("device.api") {
            print("      API: \(api)")
        }

        // Show device path if available
        if let path = device.property("device.path") {
            print("      Path: \(path)")
        } else if let path = device.property("api.v4l2.path") {
            print("      Path: \(path)")
        } else if let path = device.property("api.alsa.path") {
            print("      Path: \(path)")
        }

        // Show caps summary
        if let caps = device.caps {
            // Show first format
            if let firstFormat = caps.split(separator: ";").first {
                let trimmed = firstFormat.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 60 {
                    print("      Caps: \(trimmed.prefix(60))...")
                } else {
                    print("      Caps: \(trimmed)")
                }
            }
        }

        print()
    }
}
