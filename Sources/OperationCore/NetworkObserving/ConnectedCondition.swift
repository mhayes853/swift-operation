// MARK: - ConnectedCondition

/// A ``FetchCondition`` that detects whether or not the user is connected to a ``NetworkObserver``.
///
/// This condition checks if the current ``NetworkConnectionStatus`` on the observer is greater then the
/// ``OperationContext/satisfiedConnectionStatus`` context value. You can change that value to update
/// the threshold for what is considered "connected" for this fetch condition.
public struct ConnectedCondition {
  let observer: any NetworkObserver
}

extension ConnectedCondition: FetchCondition {
  public func isSatisfied(in context: OperationContext) -> Bool {
    self.observer.currentStatus >= context.satisfiedConnectionStatus
  }

  public func subscribe(
    in context: OperationContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> OperationSubscription {
    self.observer.subscribe { observer($0 >= context.satisfiedConnectionStatus) }
  }
}

extension FetchCondition where Self == ConnectedCondition {
  /// A ``FetchCondition`` that detects whether or not the user is connected to a ``NetworkObserver``.
  ///
  /// - Parameter observer: A ``NetworkObserver``.
  /// - Returns: A ``ConnectedCondition``.
  public static func connected(to observer: some NetworkObserver) -> Self {
    ConnectedCondition(observer: observer)
  }
}

// MARK: - Satisfied Connection Status

extension OperationContext {
  /// The minimum satisfiable ``NetworkStatus`` status to satisfy ``ConnectedCondition``.
  ///
  /// The default value is ``NetworkConnectionStatus/connected``.
  public var satisfiedConnectionStatus: NetworkConnectionStatus {
    get { self[SatisfiedConnectionStatusKey.self] }
    set { self[SatisfiedConnectionStatusKey.self] = newValue }
  }

  private struct SatisfiedConnectionStatusKey: Key {
    static let defaultValue = NetworkConnectionStatus.connected
  }
}
