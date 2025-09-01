import Foundation

/// A ``FetchCondition`` that is satisfied whenever the app is active in the foreground using an
/// ``ApplicationActivityObserver``.
public final class ApplicationIsActiveRunSpecification<
  Observer: ApplicationActivityObserver & Sendable
>: OperationRunSpecification, Sendable {
  private typealias Handler = @Sendable () -> Void
  private struct State: Sendable {
    var isActive: Bool
    var subscription = OperationSubscription.empty
  }

  private let state: RecursiveLock<State>
  private let subscriptions: OperationSubscriptions<Handler>

  public init(observer: Observer) {
    self.state = RecursiveLock(State(isActive: true))
    self.subscriptions = OperationSubscriptions<Handler>()
    self.state.withLock { state in
      state.subscription = observer.subscribe { [weak self] isActive in
        self?.state
          .withLock { state in
            guard state.isActive != isActive else { return }
            state.isActive = isActive
            self?.subscriptions.forEach { $0() }
          }
      }
    }
  }

  public func isSatisfied(in context: OperationContext) -> Bool {
    self.state.withLock { state in
      context.isApplicationActiveReRunningEnabled && state.isActive
    }
  }

  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.subscriptions.add(handler: onChange).subscription
  }
}

extension OperationRunSpecification {
  /// A ``FetchCondition`` that is satisfied whenever the app is active in the foreground using an
  /// ``ApplicationActivityObserver``.
  ///
  /// - Parameter observer: The observer to use to determine the app's active state.
  /// - Returns: A ``FetchCondition`` that is satisfied whenever the app is active in the foreground.
  public static func applicationIsActive<Observer>(
    observer: Observer
  ) -> Self where Self == ApplicationIsActiveRunSpecification<Observer> {
    ApplicationIsActiveRunSpecification(observer: observer)
  }
}
