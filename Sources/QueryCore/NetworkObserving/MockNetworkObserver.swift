// MARK: - MockNetworkObserver

/// A ``NetworkObserver`` useful for faking network conditions in your queries.
public final class MockNetworkObserver {
  private typealias Handler = @Sendable (NetworkConnectionStatus) -> Void

  private let subscriptions = QuerySubscriptions<Handler>()
  private let status: Lock<NetworkConnectionStatus>
  
  /// Creates a mock observer.
  ///
  /// - Parameter initialStatus: The initial ``NetworkStatus`` of this observer.
  public init(initialStatus: NetworkConnectionStatus = .connected) {
    self.status = Lock(initialStatus)
  }
}

// MARK: - Send Status

extension MockNetworkObserver {
  /// Sends a new ``NetworkStatus`` to all subscribers of this observer.
  ///
  /// - Parameter status: The status to send.
  public func send(status: NetworkConnectionStatus) {
    self.status.withLock { $0 = status }
    self.subscriptions.forEach { $0(status) }
  }
}

// MARK: - Subscriber Count

extension MockNetworkObserver {
  /// The number of subscribers currently subscribed to this observer.
  public var subscriberCount: Int {
    self.subscriptions.count
  }
}

// MARK: - NetworkObserver Conformance

extension MockNetworkObserver: NetworkObserver {
  public var currentStatus: NetworkConnectionStatus {
    self.status.withLock { $0 }
  }

  public func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> QuerySubscription {
    handler(self.currentStatus)
    let (subscription, _) = self.subscriptions.add(handler: handler)
    return subscription
  }
}
