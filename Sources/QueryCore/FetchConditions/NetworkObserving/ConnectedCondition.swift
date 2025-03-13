// MARK: - ConnectedCondition

public struct ConnectedCondition {
  let observer: any NetworkObserver
}

extension ConnectedCondition: FetchCondition {
  public func isSatisfied(in context: QueryContext) -> Bool {
    self.observer.currentStatus >= context.satisfiedConnectionStatus
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    self.observer.subscribe { observer($0 >= context.satisfiedConnectionStatus) }
  }
}

extension FetchCondition where Self == ConnectedCondition {
  public static func connected(to observer: some NetworkObserver) -> Self {
    ConnectedCondition(observer: observer)
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
