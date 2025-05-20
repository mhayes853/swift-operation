import Foundation

// MARK: - FocusFetchCondition

/// A ``FetchCondition`` that is satisfied whenever the app is active in the foreground based on
/// system notifications.
///
/// The default instance of this condition uses platform-specific `Notification`s to observe
/// the app lifecycle, and a check for whether or not the app's state is active.
public final class ApplicationIsActiveCondition: Sendable {
  private typealias Handler = @Sendable (Bool) -> Void
  private struct State: @unchecked Sendable {
    var isActive: Bool
  }

  private let state: LockedBox<State>
  private let subscriptions: QuerySubscriptions<Handler>
  private let observerSubscription: QuerySubscription

  fileprivate init(observer: some ApplicationActivityObserver) {
    let state = LockedBox(value: State(isActive: true))
    let subscriptions = QuerySubscriptions<Handler>()
    self.observerSubscription = observer.subscribe { isActive in
      state.inner.withLock { state in
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
  public func isSatisfied(in context: QueryContext) -> Bool {
    self.state.inner.withLock { state in
      context.isApplicationActiveRefetchingEnabled && state.isActive
    }
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
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
  public static func applicationIsActive(observer: some ApplicationActivityObserver) -> Self {
    ApplicationIsActiveCondition(observer: observer)
  }
}
