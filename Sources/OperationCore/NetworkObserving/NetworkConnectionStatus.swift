/// An enum representing the connection to a network.
public enum NetworkConnectionStatus: Int, Hashable, Sendable {
  /// The user is connected to the network.
  case connected = 2

  /// The user is disconnected from the network.
  case disconnected = 0

  /// The user is not connected to the network, but establishing a new connection may activate the connection.
  case requiresConnection = 1
}

extension NetworkConnectionStatus: Comparable {
  public static func < (lhs: NetworkConnectionStatus, rhs: NetworkConnectionStatus) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
