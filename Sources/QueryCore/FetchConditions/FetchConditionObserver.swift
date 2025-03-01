public protocol FetchConditionObserver {
  func isSatisfied(in context: QueryContext) -> Bool

  func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription
}
