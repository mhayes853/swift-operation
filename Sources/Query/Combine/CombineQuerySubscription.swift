#if canImport(Combine)
  import Combine

  // MARK: - CombineQuerySubscription

  public final class CombineQuerySubscription {
    private let base: QuerySubscription

    public init(_ subscription: QuerySubscription) {
      self.base = subscription
    }
  }

  // MARK: - Subscription Conformance

  extension CombineQuerySubscription: Subscription {
    public func cancel() {
      self.base.cancel()
    }

    public func request(_ demand: Subscribers.Demand) {
    }
  }
#endif
