public protocol FetchConditionObserver {
  var isSatisfied: Bool { get }

  func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription
}
