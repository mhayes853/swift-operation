import Query

final class TestNetworkObserver: NetworkObserver {
  typealias Handler = @Sendable (NetworkStatus) -> Void

  private let subscriptions = QuerySubscriptions<Handler>()
  private let status = RecursiveLock(NetworkStatus.connected)

  var currentStatus: NetworkStatus {
    self.status.withLock { $0 }
  }

  func subscribe(with handler: @escaping Handler) -> QuerySubscription {
    handler(self.currentStatus)
    let (subscription, _) = self.subscriptions.add(handler: handler)
    return subscription
  }

  func send(status: NetworkStatus) {
    self.status.withLock { $0 = status }
    self.subscriptions.forEach { $0(status) }
  }
}
