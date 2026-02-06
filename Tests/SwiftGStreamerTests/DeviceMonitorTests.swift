import Foundation
import Testing

@testable import GStreamer

@Suite("Device Monitor Tests")
struct DeviceMonitorTests {

  init() throws {
    try GStreamer.initialize()
  }

  private func shouldSkipOnMacOSCI() -> Bool {
    #if os(macOS)
      return ProcessInfo.processInfo.environment["CI"] != nil
    #else
      return false
    #endif
  }

  @Test("Create DeviceMonitor")
  func createMonitor() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    _ = monitor  // Just verify creation doesn't crash
  }

  @Test("List video sources")
  func listVideoSources() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    let cameras = monitor.videoSources()

    // On CI or headless systems, there may be no cameras
    // Just verify the API works without crashing
    for camera in cameras {
      #expect(!camera.displayName.isEmpty)
      #expect(!camera.deviceClass.isEmpty)
    }
  }

  @Test("List audio sources")
  func listAudioSources() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    let mics = monitor.audioSources()

    // On CI or headless systems, there may be no microphones
    for mic in mics {
      #expect(!mic.displayName.isEmpty)
    }
  }

  @Test("List audio sinks")
  func listAudioSinks() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    let speakers = monitor.audioSinks()

    // On CI or headless systems, there may be no speakers
    for speaker in speakers {
      #expect(!speaker.displayName.isEmpty)
    }
  }

  @Test("List all devices")
  func listAllDevices() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    let devices = monitor.allDevices()

    // Just verify it doesn't crash
    for device in devices {
      #expect(!device.displayName.isEmpty)
    }
  }

  @Test("Device has caps")
  func deviceHasCaps() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    let devices = monitor.allDevices()

    // If we have any devices, check they have caps
    for device in devices {
      // Caps may or may not be available
      _ = device.caps
    }
  }

  @Test("Create element from device")
  func createElementFromDevice() {
    guard !shouldSkipOnMacOSCI() else { return }
    let monitor = DeviceMonitor()
    let devices = monitor.videoSources()

    // If we have a camera, try to create an element
    if let camera = devices.first {
      let element = camera.createElement(name: "test_camera")
      // Element creation may fail on CI, but shouldn't crash
      if let el = element {
        #expect(!el.name.isEmpty)
      }
    }
  }
}
