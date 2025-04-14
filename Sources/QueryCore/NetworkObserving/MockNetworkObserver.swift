// MARK: - MockNetworkObserver

/// A ``NetworkObserver`` useful for faking network conditions in your queries.
public final class MockNetworkObserver {
  public typealias Handler = @Sendable (NetworkStatus) -> Void

  private let subscriptions = QuerySubscriptions<Handler>()
  private let status: Lock<NetworkStatus>
  
  /// Creates a mock observer.
  ///
  /// - Parameter initialStatus: The initial ``NetworkStatus`` of this observer.
  public init(initialStatus: NetworkStatus = .connected) {
    self.status = Lock(initialStatus)
  }
}

// MARK: - Send Status

extension MockNetworkObserver {
  /// Sends a new ``NetworkStatus`` to all subscribers of this observer.
  ///
  /// - Parameter status: The status to send.
  public func send(status: NetworkStatus) {
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
  public var currentStatus: NetworkStatus {
    self.status.withLock { $0 }
  }

  public func subscribe(with handler: @escaping Handler) -> QuerySubscription {
    handler(self.currentStatus)
    let (subscription, _) = self.subscriptions.add(handler: handler)
    return subscription
  }
}
