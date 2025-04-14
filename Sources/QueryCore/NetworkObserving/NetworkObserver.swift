// MARK: - NetworkStatus

/// An enum representing the connection to a network.
public enum NetworkStatus: Int, Hashable, Sendable {
  /// The user is connected to the network.
  case connected = 2
  
  /// The user is disconnected from the network.
  case disconnected = 0
  
  /// The user is not connected to the network, but establishing a new connection may activate the connection.
  case requiresConnection = 1
}

extension NetworkStatus: Comparable {
  public static func < (lhs: NetworkStatus, rhs: NetworkStatus) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

// MARK: - NetworkObserver

/// A protocol for observing the current network connection status.
public protocol NetworkObserver: Sendable {
  /// The current ``NetworkStatus`` from this observer.
  var currentStatus: NetworkStatus { get }
  
  /// Subscribes to the ``NetworkStatus`` from this observer.
  ///
  /// - Parameter handler: A closure to yield back the latest network status.
  /// - Returns: A ``QuerySubscription``.
  func subscribe(with handler: @escaping @Sendable (NetworkStatus) -> Void) -> QuerySubscription
}
