import Foundation

// MARK: - ApplicationIsActiveCondition

/// A ``FetchCondition`` that is satisfied whenever the app is active in the foreground using an
/// ``ApplicationActivityObserver``.
public final class ApplicationIsActiveCondition: Sendable {
  private typealias Handler = @Sendable (Bool) -> Void
  private struct State: @unchecked Sendable {
    var isActive: Bool
  }

  private let state: LockedBox<State>
  private let subscriptions: OperationSubscriptions<Handler>
  private let observerSubscription: OperationSubscription

  fileprivate init(observer: some ApplicationActivityObserver) {
    let state = LockedBox(value: State(isActive: true))
    let subscriptions = OperationSubscriptions<Handler>()
    self.observerSubscription = observer.subscribe { isActive in
      state.inner.withLock { state in
        guard state.isActive != isActive else { return }
        state.isActive = isActive
        subscriptions.forEach { $0(isActive) }
      }
    }
    self.state = state
    self.subscriptions = subscriptions
  }
}

// MARK: - FetchConditionObserver Conformance

extension ApplicationIsActiveCondition: FetchCondition {
  public func isSatisfied(in context: OperationContext) -> Bool {
    self.state.inner.withLock { state in
      context.isApplicationActiveRefetchingEnabled && state.isActive
    }
  }

  public func subscribe(
    in context: OperationContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> OperationSubscription {
    guard context.isApplicationActiveRefetchingEnabled else {
      observer(false)
      return .empty
    }
    return self.state.inner.withLock { state in
      observer(state.isActive)
      return self.subscriptions.add(handler: observer).subscription
    }
  }
}

extension FetchCondition where Self == ApplicationIsActiveCondition {
  /// A ``FetchCondition`` that is satisfied whenever the app is active in the foreground using an
  /// ``ApplicationActivityObserver``.
  ///
  /// - Parameter observer: The observer to use to determine the app's active state.
  /// - Returns: A ``FetchCondition`` that is satisfied whenever the app is active in the foreground.
  public static func applicationIsActive(observer: some ApplicationActivityObserver) -> Self {
    ApplicationIsActiveCondition(observer: observer)
  }
}
