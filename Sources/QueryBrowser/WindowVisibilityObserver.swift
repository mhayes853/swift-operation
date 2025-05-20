#if canImport(JavaScriptKit)
  import JavaScriptKit
  import JavaScriptEventLoop
  import QueryCore

  /// An `ApplicationActivityObserver` that observes whether or not the browser window is visible.
  public struct WindowVisibilityObserver {
    let documentProperty: String
  }

  extension WindowVisibilityObserver: ApplicationActivityObserver {
    public func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> QuerySubscription {
      let window = JSObject.global.window.object!
      let document = window[dynamicMember: self.documentProperty].object!
      handler(document.visibilityState == .string("visible"))
      let listener = JSClosure { _ in
        handler(document.visibilityState == .string("visible"))
        return .undefined
      }
      window.addEventListener!("visibilitychange", listener)
      return .jsOneshotClosure { _ in
        window.removeEventListener!("visibilitychange", listener)
        return .undefined
      }
    }
  }

  extension ApplicationActivityObserver where Self == WindowVisibilityObserver {
    /// An `ApplicationActivityObserver` that observes whether or not the browser window is visible.
    public static var windowVisibility: Self {
      .windowVisibility(documentProperty: "document")
    }

    /// An `ApplicationActivityObserver` that observes whether or not the browser window is visible.
    ///
    /// - Parameter documentProperty: The property name of `window.document`.
    public static func windowVisibility(documentProperty: String) -> Self {
      WindowVisibilityObserver(documentProperty: documentProperty)
    }
  }
#endif
