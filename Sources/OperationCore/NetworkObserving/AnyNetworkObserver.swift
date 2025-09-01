// MARK: - AnyNetworkObserver

public struct AnyNetworkObserver: NetworkObserver {
  public let base: any NetworkObserver

  public var currentStatus: NetworkConnectionStatus { self.base.currentStatus }

  public init(_ base: any NetworkObserver) {
    self.base = base
  }

  public func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> OperationSubscription {
    self.base.subscribe(with: handler)
  }
}

// MARK: - AnySendableNetworkObserver

public struct AnySendableNetworkObserver: NetworkObserver, Sendable {
  public let base: any NetworkObserver & Sendable

  public var currentStatus: NetworkConnectionStatus { self.base.currentStatus }

  public init(_ base: any NetworkObserver & Sendable) {
    self.base = base
  }

  public func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> OperationSubscription {
    self.base.subscribe(with: handler)
  }
}
