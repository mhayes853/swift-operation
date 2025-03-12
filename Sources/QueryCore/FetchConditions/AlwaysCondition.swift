public struct AlwaysCondition: FetchCondition {
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

extension FetchCondition where Self == AlwaysCondition {
  public static func always(_ value: Bool) -> Self {
    Self(isTrue: value)
  }
}
