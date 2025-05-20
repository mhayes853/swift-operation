#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryCore

  public struct WindowVisibilityObserver {
    let documentProperty: String
  }

  extension WindowVisibilityObserver: ApplicationActivityObserver {
    public func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> QuerySubscription {
      let window = JSObject.global.window.object!
      let document = window[dynamicMember: self.documentProperty].object!
      handler(document.visibilityState == .string("visible"))
      nonisolated(unsafe) let listener = JSClosure { _ in
        handler(document.visibilityState == .string("visible"))
        return .undefined
      }
      window.addEventListener!("visibilitychange", listener)
      return QuerySubscription {
        JSObject.global.window.object!.removeEventListener!("visibilitychange", listener)
      }
    }
  }

  extension ApplicationActivityObserver where Self == WindowVisibilityObserver {
    public static var windowVisibility: Self {
      .windowVisibility(documentProperty: "document")
    }

    public static func windowVisibility(
      documentProperty: String
    ) -> Self {
      WindowVisibilityObserver(documentProperty: documentProperty)
    }
  }
#endif
