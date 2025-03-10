public struct AlwaysObserver: FetchConditionObserver {
  let isTrue: Bool

  public func isSatisfied(in context: QueryContext) -> Bool {
    isTrue
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    .empty
  }
}

extension FetchConditionObserver where Self == AlwaysObserver {
  public static func always(_ value: Bool) -> Self {
    Self(isTrue: value)
  }
}
