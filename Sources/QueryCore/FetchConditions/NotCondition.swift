public struct NotCondition<Base: FetchCondition> {
  let base: Base

  public func isSatisfied(in context: QueryContext) -> Bool {
    !base.isSatisfied(in: context)
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    base.subscribe(in: context) { satisfied in
      observer(!satisfied)
    }
  }
}

public prefix func ! <Base: FetchCondition>(
  _ base: Base
) -> NotCondition<Base> {
  NotCondition(base: base)
}
