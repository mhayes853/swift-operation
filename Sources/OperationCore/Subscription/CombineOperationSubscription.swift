#if canImport(Combine)
  import Combine

  // MARK: - CombineOperationSubscription

  /// A Combine `Subscription` conformance that wraps a ``OperationSubscription``.
  ///
  /// Use this type if you need to integrate a `OperationSubscription` with a Combine `Publisher`.
  public final class CombineOperationSubscription {
    private let base: OperationSubscription

    /// Creates a Combine subscription.
    ///
    /// - Parameter subscription: A ``OperationSubscription``.
    public init(_ subscription: OperationSubscription) {
      self.base = subscription
    }
  }

  // MARK: - Subscription Conformance

  extension CombineOperationSubscription: Subscription {
    public func cancel() {
      self.base.cancel()
    }

    public func request(_ demand: Subscribers.Demand) {
    }
  }
#endif
