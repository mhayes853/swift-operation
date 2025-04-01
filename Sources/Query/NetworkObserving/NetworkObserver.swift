// MARK: - NetworkStatus

public enum NetworkStatus: Int, Hashable, Sendable {
  case connected = 2
  case disconnected = 0
  case requiresConnection = 1
}

extension NetworkStatus: Comparable {
  public static func < (lhs: NetworkStatus, rhs: NetworkStatus) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

// MARK: - NetworkObserver

public protocol NetworkObserver: Sendable {
  var currentStatus: NetworkStatus { get }
  func subscribe(with handler: @escaping @Sendable (NetworkStatus) -> Void) -> QuerySubscription
}
