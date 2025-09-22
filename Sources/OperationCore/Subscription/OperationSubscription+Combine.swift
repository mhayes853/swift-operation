#if canImport(Combine)
  import Combine

  extension OperationSubscription {
    /// A Combine `Subscription` conformance that wraps an ``OperationSubscription``.
    ///
    /// Use this type if you need to integrate a `OperationSubscription` with a Combine `Publisher`.
    public final class Combine: Subscription {
      private let subscription: OperationSubscription

      /// Creates a Combine subscription.
      ///
      /// - Parameter subscription: A ``OperationSubscription``.
      public init(_ subscription: OperationSubscription) {
        self.subscription = subscription
      }

      public func request(_ demand: Subscribers.Demand) {}

      public func cancel() {
        self.subscription.cancel()
      }
    }
  }
#endif
