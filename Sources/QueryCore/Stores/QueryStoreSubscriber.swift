public typealias QueryStoreSubscriber<Value: Sendable> = @Sendable (
  QueryStoreSubscription.Event<Value>
) -> Void
