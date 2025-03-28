#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryCore

  public struct WindowFocusCondition: @unchecked Sendable {
    fileprivate let document: JSObject
    fileprivate let window: JSObject
  }

  extension WindowFocusCondition: FetchCondition {
    public func isSatisfied(in context: QueryContext) -> Bool {
      self.document.visibilityState == .string("visible")
    }

    public func subscribe(
      in context: QueryContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      observer(self.isSatisfied(in: context))
      nonisolated(unsafe) let listener = JSClosure { _ in
        observer(self.isSatisfied(in: context))
        return .undefined
      }
      self.window.addEventListener!("visibilitychange", listener)
      return QuerySubscription {
        self.window.removeEventListener!("visibilitychange", listener)
      }
    }
  }

  extension FetchCondition where Self == WindowFocusCondition {
    public static var windowFocus: Self {
      WindowFocusCondition(
        document: JSObject.global.document.object!,
        window: JSObject.global.window.object!
      )
    }

    public static func windowFocus(document: JSObject, window: JSObject) -> Self {
      WindowFocusCondition(document: document, window: window)
    }
  }
#endif
