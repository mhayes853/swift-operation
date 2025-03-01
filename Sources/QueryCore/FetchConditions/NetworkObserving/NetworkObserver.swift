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

public protocol NetworkObserver: FetchConditionObserver, Sendable {
  var currentStatus: NetworkStatus { get }
  func subscribe(with handler: @escaping @Sendable (NetworkStatus) -> Void) -> QuerySubscription
}

extension NetworkObserver {
  public func isSatisfied(in context: QueryContext) -> Bool {
    self.currentStatus >= context.satisfiedConnectionStatus
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    self.subscribe { observer($0 >= context.satisfiedConnectionStatus) }
  }
}

// MARK: - Satisfied Connection Status

extension QueryContext {
  public var satisfiedConnectionStatus: NetworkStatus {
    get { self[SatisfiedConnectionStatusKey.self] }
    set { self[SatisfiedConnectionStatusKey.self] = newValue }
  }

  private struct SatisfiedConnectionStatusKey: Key {
    static let defaultValue = NetworkStatus.connected
  }
}
