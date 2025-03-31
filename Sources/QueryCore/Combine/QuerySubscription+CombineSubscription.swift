#if canImport(Combine)
  import Combine

  extension QuerySubscription: Subscription {
    public func request(_ demand: Subscribers.Demand) {}
  }
#endif
