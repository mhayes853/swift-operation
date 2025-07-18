import Dependencies

#if canImport(UIKit)
  import UIKit
#endif

#if canImport(AppKit)
  import AppKit
#endif

// MARK: - DeviceInfo

public struct DeviceInfo: Hashable, Sendable {
  public let localizedModelName: String
  public let settingsURL: URL

  public init(localizedModelName: String, settingsURL: URL) {
    self.localizedModelName = localizedModelName
    self.settingsURL = settingsURL
  }
}

// MARK: - Current

@MainActor
extension DeviceInfo {
  #if os(iOS)
    public static var current: Self {
      DeviceInfo(
        localizedModelName: UIDevice.current.localizedModel,
        settingsURL: URL(string: UIApplication.openSettingsURLString)!
      )
    }
  #else
    public static var current: Self {
      DeviceInfo(
        localizedModelName: "Mac",
        settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.appleaccount")!
      )
    }
  #endif
}

// MARK: - DependencyKey

extension DeviceInfo: TestDependencyKey {
  public static let testValue = Self(
    localizedModelName: "Test Device",
    settingsURL: URL(string: "https://example.com/settings")!
  )
}
