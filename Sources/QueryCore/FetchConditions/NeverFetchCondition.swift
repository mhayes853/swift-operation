public struct NeverFetchCondition: FetchConditionObserver {
  public func isSatisfied(in context: QueryContext) -> Bool {
    false
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    .empty
  }
}

extension FetchConditionObserver where Self == NeverFetchCondition {
  public static var never: Self {
    NeverFetchCondition()
  }
}
