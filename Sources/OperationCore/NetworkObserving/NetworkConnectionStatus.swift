/// An enum representing the connection to a network.
public enum NetworkConnectionStatus: Hashable, Sendable {
  /// The user is connected to the network.
  case connected

  /// The user is disconnected from the network.
  case disconnected

  /// The user is not connected to the network, but establishing a new connection may activate the connection.
  case requiresConnection
}

extension NetworkConnectionStatus: Comparable {
  public static func < (lhs: NetworkConnectionStatus, rhs: NetworkConnectionStatus) -> Bool {
    lhs.compareValue < rhs.compareValue
  }
  
  private var compareValue: Int {
    switch self {
    case .connected: 2
    case .disconnected: 0
    case .requiresConnection: 1
    }
  }
}
