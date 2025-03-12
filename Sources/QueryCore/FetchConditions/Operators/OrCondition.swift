public struct OrCondition<Left: FetchCondition, Right: FetchCondition> {
  let left: Left
  let right: Right
}

extension OrCondition: FetchCondition {
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

public func || <Left: FetchCondition, Right: FetchCondition>(
  _ left: Left,
  _ right: Right
) -> OrCondition<Left, Right> {
  OrCondition(left: left, right: right)
}
