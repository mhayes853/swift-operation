import Foundation

package var isRunningInWatchExtension: Bool {
  #if os(watchOS)
    let bundleURL = Bundle.main.bundleURL
    let lastPath = bundleURL.lastPathComponent.lowercased()
    if bundleURL.pathExtension == "appex" || lastPath.contains("appex") {
      return true
    }
    if Bundle.main.infoDictionary?["NSExtension"] != nil {
      return true
    }
    return false
  #else
    false
  #endif
}
