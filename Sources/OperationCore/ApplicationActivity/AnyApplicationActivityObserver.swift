// MARK: - AnyApplicationActivityObserver

public struct AnyApplicationActivityObserver: ApplicationActivityObserver {
  public let base: any ApplicationActivityObserver

  public init(_ base: any ApplicationActivityObserver) {
    self.base = base
  }

  public func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> OperationSubscription {
    self.base.subscribe(handler)
  }
}

// MARK: - AnySendableApplicationActivityObserver

public struct AnySendableApplicationActivityObserver: ApplicationActivityObserver, Sendable {
  public let base: any ApplicationActivityObserver & Sendable

  public init(_ base: any ApplicationActivityObserver & Sendable) {
    self.base = base
  }

  public func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> OperationSubscription {
    self.base.subscribe(handler)
  }
}
