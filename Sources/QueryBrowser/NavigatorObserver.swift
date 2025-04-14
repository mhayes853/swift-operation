#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryCore

  // MARK: - NavigatorObserver

  public final class NavigatorObserver: @unchecked Sendable {
    private let navigator: JSObject
    private let window: JSObject

    public init(navigator: JSObject, window: JSObject) {
      self.navigator = navigator
      self.window = window
    }
  }

  // MARK: - Shared

  extension NavigatorObserver {
    public static let shared = NavigatorObserver(
      navigator: JSObject.global.navigator.object!,
      window: JSObject.global.window.object!
    )
  }

  // MARK: - NetworkObserver Conformance

  extension NavigatorObserver: NetworkObserver {
    public var currentStatus: NetworkStatus {
      self.navigator.onLine == .boolean(true) ? .connected : .disconnected
    }

    public func subscribe(
      with handler: @escaping @Sendable (NetworkStatus) -> Void
    ) -> QuerySubscription {
      handler(self.currentStatus)
      nonisolated(unsafe) let onlineListener = JSClosure { _ in
        handler(.connected)
        return .undefined
      }
      nonisolated(unsafe) let offlineListener = JSClosure { _ in
        handler(.disconnected)
        return .undefined
      }
      self.window.addEventListener!("online", onlineListener)
      self.window.addEventListener!("offline", offlineListener)
      return QuerySubscription {
        self.window.removeEventListener!("online", onlineListener)
        self.window.removeEventListener!("offline", offlineListener)
      }
    }
  }
#endif
