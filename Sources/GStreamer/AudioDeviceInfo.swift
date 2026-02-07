/// A discovered audio device (microphone or speaker).
///
/// AudioDeviceInfo provides a cross-platform summary of an audio device and its
/// reported capabilities. Use ``AudioSource/availableMicrophones()`` or
/// ``AudioSink/availableSpeakers()`` to enumerate devices.
public struct AudioDeviceInfo: Sendable, Hashable {
  /// Audio device type.
  public enum DeviceType: Sendable, Hashable {
    case input
    case output
  }

  /// Capabilities reported by the device (if available).
  public struct Capabilities: Sendable, Hashable {
    public let sampleRates: [Int]
    public let channels: [Int]
    public let formats: [AudioFormat]

    public init(sampleRates: [Int], channels: [Int], formats: [AudioFormat]) {
      self.sampleRates = sampleRates
      self.channels = channels
      self.formats = formats
    }
  }

  public let index: Int
  public let name: String
  public let uniqueID: String
  public let type: DeviceType
  public let capabilities: Capabilities

  public init(
    index: Int,
    name: String,
    uniqueID: String,
    type: DeviceType,
    capabilities: Capabilities
  ) {
    self.index = index
    self.name = name
    self.uniqueID = uniqueID
    self.type = type
    self.capabilities = capabilities
  }
}
