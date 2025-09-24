// MARK: - ConnectedCondition

/// An ``OperationRunSpecification`` that is satisfied when connected to the network via a
/// ``NetworkObserver``.
///
/// This condition checks if the current ``NetworkConnectionStatus`` on the observer is greater
/// then the ``OperationContext/satisfiedConnectionStatus`` context value. You can change that
/// value to update the threshold for what is considered "connected" for this fetch condition.
public struct NetworkConnectionRunSpecification<
  Observer: NetworkObserver
>: OperationRunSpecification {
  private let observer: Observer

  public init(observer: Observer) {
    self.observer = observer
  }

  public func isSatisfied(in context: OperationContext) -> Bool {
    self.observer.currentStatus >= context.satisfiedConnectionStatus
  }

  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.observer.subscribe { _ in onChange() }
  }
}

extension NetworkConnectionRunSpecification: Sendable where Observer: Sendable {}

extension OperationRunSpecification {
  /// An ``OperationRunSpecification`` that is satisfied when connected to the network via a
  /// ``NetworkObserver``.
  ///
  /// - Parameter observer: A ``NetworkObserver``.
  /// - Returns: A ``NetworkConnectionRunSpecification``.
  public static func connected<Observer>(to observer: Observer) -> Self
  where Self == NetworkConnectionRunSpecification<Observer> {
    NetworkConnectionRunSpecification(observer: observer)
  }
}
