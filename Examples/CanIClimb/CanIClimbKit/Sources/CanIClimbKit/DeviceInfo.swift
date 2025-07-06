#if canImport(UIKit)
  import UIKit
#endif

#if canImport(AppKit)
  import AppKit
#endif

// MARK: - LocalizedModelName

@MainActor
public var localizedModelName: String {
  #if os(iOS)
    UIDevice.current.localizedModel
  #else
    "Mac"
  #endif
}

// MARK: - Settings URL

@MainActor
public var settingsURL: URL {
  #if os(iOS)
    URL(string: UIApplication.openSettingsURLString)!
  #else
    URL(string: "x-apple.systempreferences:com.apple.preference.appleaccount")!
  #endif
}
