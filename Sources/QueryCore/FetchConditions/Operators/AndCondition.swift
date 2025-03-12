public struct AndCondition<Left: FetchCondition, Right: FetchCondition> {
  let left: Left
  let right: Right
}

extension AndCondition: FetchCondition {
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

public func && <Left: FetchCondition, Right: FetchCondition>(
  _ left: Left,
  _ right: Right
) -> AndCondition<Left, Right> {
  AndCondition(left: left, right: right)
}
