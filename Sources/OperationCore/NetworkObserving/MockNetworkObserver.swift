/// A ``NetworkObserver`` useful for faking network conditions in your queries.
public final class MockNetworkObserver: NetworkObserver, Sendable {
  private typealias Handler = @Sendable (NetworkConnectionStatus) -> Void

  private let subscriptions = OperationSubscriptions<Handler>()
  private let status: Lock<NetworkConnectionStatus>

  /// The number of subscribers currently subscribed to this observer.
  public var subscriberCount: Int {
    self.subscriptions.count
  }

  public var currentStatus: NetworkConnectionStatus {
    self.status.withLock { $0 }
  }

  /// Creates a mock observer.
  ///
  /// - Parameter initialStatus: The initial ``NetworkConnectionStatus`` of this observer.
  public init(initialStatus: NetworkConnectionStatus = .connected) {
    self.status = Lock(initialStatus)
  }

  /// Sends a new ``NetworkConnectionStatus`` to all subscribers of this observer.
  ///
  /// - Parameter status: The status to send.
  public func send(status: NetworkConnectionStatus) {
    self.status.withLock { $0 = status }
    self.subscriptions.forEach { $0(status) }
  }

  public func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> OperationSubscription {
    handler(self.currentStatus)
    let (subscription, _) = self.subscriptions.add(handler: handler)
    return subscription
  }
}
