public struct AnyFetchCondition: FetchCondition {
  public let base: any FetchCondition

  public init(_ condition: some FetchCondition) {
    self.base = condition
  }

  public func isSatisfied(in context: QueryContext) -> Bool {
    self.base.isSatisfied(in: context)
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    self.base.subscribe(in: context, observer)
  }
}
