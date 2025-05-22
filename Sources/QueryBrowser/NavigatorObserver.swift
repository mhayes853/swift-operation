#if canImport(JavaScriptKit)
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
    public var currentStatus: NetworkStatus {
      let window = JSObject.global.window.object!
      return window[dynamicMember: self.navigatorProperty].onLine == .boolean(true)
        ? .connected
        : .disconnected
    }

    public func subscribe(
      with handler: @escaping @Sendable (NetworkStatus) -> Void
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
      window.addEventListener!("online", onlineListener)
      window.addEventListener!("offline", offlineListener)
      return .jsClosure { _ in
        window.removeEventListener!("online", onlineListener)
        window.removeEventListener!("offline", offlineListener)
        return .undefined
      }
    }
  }
#endif
