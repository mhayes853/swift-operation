#if canImport(JavaScriptKit) && canImport(JavaScriptEventLoop)
  import JavaScriptEventLoop
  import JavaScriptKit
  import OperationCore

  /// An `ApplicationActivityObserver` that observes whether or not the browser window is visible.
  public struct WindowVisibilityObserver: ApplicationActivityObserver, Sendable {
    /// The shared window visibility observer.
    public static let shared = WindowVisibilityObserver()

    private let documentProperty: String

    package init(documentProperty: String) {
      self.documentProperty = documentProperty
    }

    public init() {
      self.init(documentProperty: "document")
    }

    public func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> OperationSubscription {
      let window = JSObject.global.window.object!
      let document = window[dynamicMember: self.documentProperty].object!
      handler(document.visibilityState == .string("visible"))
      let listener = JSClosure { _ in
        handler(document.visibilityState == .string("visible"))
        return .undefined
      }
      _ = window.addEventListener!("visibilitychange", listener)
      return .jsClosure { _ in
        _ = window.removeEventListener!("visibilitychange", listener)
        return .undefined
      }
    }
  }
#endif
