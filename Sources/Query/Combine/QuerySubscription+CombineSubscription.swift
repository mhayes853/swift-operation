#if canImport(Combine)
  import Combine

  extension QuerySubscription: CustomCombineIdentifierConvertible {
    public var combineIdentifier: CombineIdentifier {
      CombineIdentifier()
    }
  }

  extension QuerySubscription: Subscription {
    public func request(_ demand: Subscribers.Demand) {}
  }
#endif
