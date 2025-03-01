// MARK: - NetworkStatus

public enum NetworkStatus: Hashable, Sendable {
  case connected
  case disconnected
  case requiresConnection
}

// MARK: - NetworkObserver

public protocol NetworkObserver: FetchConditionObserver, Sendable {
  var currentStatus: NetworkStatus { get }
  func subscribe(with handler: @escaping @Sendable (NetworkStatus) -> Void) -> QuerySubscription
}

// TODO: - Should `requiresConnection` also be satisfiable?

extension NetworkObserver {
  public var isSatisfied: Bool { self.currentStatus == .connected }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    QuerySubscription {}
  }
}
