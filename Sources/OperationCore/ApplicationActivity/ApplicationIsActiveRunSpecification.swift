import Foundation

/// An ``OperationRunSpecification`` that is satisfied whenever the app is active in the foreground
/// according to an ``ApplicationActivityObserver``.
public final class ApplicationIsActiveRunSpecification: OperationRunSpecification, Sendable {
  private typealias Handler = @Sendable () -> Void
  private struct State: Sendable {
    var isActive: Bool
    var subscription = OperationSubscription.empty
  }

  private let state: RecursiveLock<State>
  private let subscriptions: OperationSubscriptions<Handler>
  
  public init(observer: some ApplicationActivityObserver) {
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
      context.isApplicationActiveRerunningEnabled && state.isActive
    }
  }

  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.subscriptions.add(handler: onChange).subscription
  }
}

extension OperationRunSpecification where Self == ApplicationIsActiveRunSpecification {
  /// An ``OperationRunSpecification`` that is satisfied whenever the app is active in the foreground
  /// according to an ``ApplicationActivityObserver``.
  ///
  /// - Parameter observer: The observer to use to determine the app's activity state.
  /// - Returns: An ``OperationRunSpecification`` that is satisfied whenever the app is active in
  ///   the foreground.
  public static func applicationIsActive(observer: some ApplicationActivityObserver) -> Self {
    ApplicationIsActiveRunSpecification(observer: observer)
  }
}
