#if canImport(Combine)
  import Combine

  // MARK: - CombineQuerySubscription

  /// A Combine `Subscription` conformance that wraps a ``QuerySubscription``.
  ///
  /// Use this type if you need to integrate a `QuerySubscription` with a Combine `Publisher`.
  public final class CombineQuerySubscription {
    private let base: QuerySubscription
    
    /// Creates a Combine subscription.
    ///
    /// - Parameter subscription: A ``QuerySubscription``.
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
