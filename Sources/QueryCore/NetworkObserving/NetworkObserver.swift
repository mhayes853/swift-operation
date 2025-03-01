#if canImport(Network)
  import Network
#endif

// MARK: - NetworkStatus

public enum NetworkStatus: Hashable, Sendable {
  case connected
  case disconnected
  case requiresConnection
}

// MARK: - NetworkObserver

public protocol NetworkObserver: Sendable {
  var currentStatus: NetworkStatus { get }
  func subscribe(with handler: @escaping @Sendable (NetworkStatus) -> Void) -> QuerySubscription
}
