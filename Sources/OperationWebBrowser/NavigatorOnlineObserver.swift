#if canImport(JavaScriptKit)
  import JavaScriptKit
  import OperationCore

  // MARK: - NavigatorObserver

  /// A `NetworkObserver` that uses the window navigator.
  public struct NavigatorOnlineObserver: NetworkObserver, Sendable {
    /// The shared navigator observer.
    public static let shared = NavigatorOnlineObserver()

    private let navigatorProperty: String

    public var currentStatus: NetworkConnectionStatus {
      let window = JSObject.global.window.object!
      return window[dynamicMember: self.navigatorProperty].onLine == .boolean(true)
        ? .connected
        : .disconnected
    }

    public init() {
      self.init(navigatorProperty: "navigator")
    }

    package init(navigatorProperty: String) {
      self.navigatorProperty = navigatorProperty
    }

    public func subscribe(
      with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
    ) -> OperationSubscription {
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
#endif
