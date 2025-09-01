/// A protocol for observing the current network connection status.
public protocol NetworkObserver {
  /// The current ``NetworkConnectionStatus`` from this observer.
  var currentStatus: NetworkConnectionStatus { get }

  /// Subscribes to the ``NetworkConnectionStatus`` from this observer.
  ///
  /// - Parameter handler: A closure to yield back the latest network status.
  /// - Returns: A ``OperationSubscription``.
  func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> OperationSubscription
}
