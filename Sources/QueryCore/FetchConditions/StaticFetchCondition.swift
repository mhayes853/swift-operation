public struct StaticFetchConditionObserver: FetchConditionObserver {
  let isTrue: Bool

  public func isSatisfied(in context: QueryContext) -> Bool {
    isTrue
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    observer(self.isTrue)
    return .empty
  }
}

extension FetchConditionObserver where Self == StaticFetchConditionObserver {
  public static func `is`(_ value: Bool) -> Self {
    StaticFetchConditionObserver(isTrue: value)
  }

  public static var `true`: Self {
    StaticFetchConditionObserver(isTrue: true)
  }

  public static var `false`: Self {
    StaticFetchConditionObserver(isTrue: false)
  }
}
