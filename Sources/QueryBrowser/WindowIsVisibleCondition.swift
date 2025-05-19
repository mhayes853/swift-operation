#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryCore

  // MARK: - WindowIsVisibleCondition

  /// A `FetchCondition` that is satisfied whenever the app is active in the foreground based on
  /// when the browser tab visibility changes.
  public struct WindowIsVisibleCondition: @unchecked Sendable {
    fileprivate let document: JSObject
    fileprivate let window: JSObject
  }

  // MARK: - FetchCondition Conformance

  extension WindowIsVisibleCondition: FetchCondition {
    public func isSatisfied(in context: QueryContext) -> Bool {
      context.isApplicationActiveRefetchingEnabled
        && self.document.visibilityState == .string("visible")
    }

    public func subscribe(
      in context: QueryContext,
      _ observer: @escaping @Sendable (Bool) -> Void
    ) -> QuerySubscription {
      guard context.isApplicationActiveRefetchingEnabled else {
        observer(false)
        return .empty
      }

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

  extension FetchCondition where Self == WindowIsVisibleCondition {
    /// A `FetchCondition` that is satisfied whenever the app is active in the foreground based on
    /// when the browser tab visibility changes.
    public static var windowIsVisible: Self {
      WindowIsVisibleCondition(
        document: JSObject.global.document.object!,
        window: JSObject.global.window.object!
      )
    }

    /// A `FetchCondition` that is satisfied whenever the app is active in the foreground based on
    /// when the browser tab visibility changes.
    ///
    /// - Parameters:
    ///   - document: The global document object.
    ///   - window: The global window object.
    /// - Returns: A `FetchCondition`
    public static func windowIsVisible(document: JSObject, window: JSObject) -> Self {
      WindowIsVisibleCondition(document: document, window: window)
    }
  }
#endif
