public struct AlwaysFetchCondition: FetchConditionObserver {
  public func isSatisfied(in context: QueryContext) -> Bool {
    true
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    .empty
  }
}

extension FetchConditionObserver where Self == AlwaysFetchCondition {
  public static var always: Self {
    AlwaysFetchCondition()
  }
}
