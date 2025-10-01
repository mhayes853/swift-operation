import Foundation

public struct DeviceName: Hashable, Sendable, Codable, RawRepresentable {
  public static let current = {
    var size: size_t = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    let name = String(cString: &machine, encoding: String.Encoding.utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return Self(rawValue: name ?? "Unknown Device")
  }()

  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}
