import JavaScriptKit
import QueryCore

// MARK: - NavigatorObserver

/// A `NetworkObserver` that uses the window navigator.
public struct NavigatorObserver {
  private let navigatorProperty: String

  public init() {
    self.init(navigatorProperty: "navigator")
  }

  package init(navigatorProperty: String) {
    self.navigatorProperty = navigatorProperty
  }
}

// MARK: - Shared

extension NavigatorObserver {
  /// The shared navigator observer.
  public static let shared = NavigatorObserver()
}

// MARK: - NetworkObserver Conformance

extension NavigatorObserver: NetworkObserver {
  public var currentStatus: NetworkConnectionStatus {
    let window = JSObject.global.window.object!
    return window[dynamicMember: self.navigatorProperty].onLine == .boolean(true)
      ? .connected
      : .disconnected
  }

  public func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> QuerySubscription {
    let window = JSObject.global.window.object!
    handler(self.currentStatus)
    let onlineListener = JSClosure { _ in
      handler(.connected)
      return .undefined
    }
    let offlineListener = JSClosure { _ in
      handler(.disconnected)
      return .undefined
    }
    _ = window.addEventListener!("online", onlineListener)
    _ = window.addEventListener!("offline", offlineListener)
    return .jsClosure { _ in
      _ = window.removeEventListener!("online", onlineListener)
      _ = window.removeEventListener!("offline", offlineListener)
      return .undefined
    }
  }
}
