public struct AndCondition<Left: FetchCondition, Right: FetchCondition> {
  let left: Left
  let right: Right
}

extension AndCondition: FetchCondition {
  public func isSatisfied(in context: QueryContext) -> Bool {
    self.left.isSatisfied(in: context) && self.right.isSatisfied(in: context)
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    let state = Lock(
      (left: self.left.isSatisfied(in: context), right: self.right.isSatisfied(in: context))
    )
    let s1 = self.left.subscribe(in: context) { value in
      state.withLock {
        $0.left = value
        observer($0.left && $0.right)
      }
    }
    let s2 = self.right.subscribe(in: context) { value in
      state.withLock {
        $0.right = value
        observer($0.left && $0.right)
      }
    }
    return QuerySubscription {
      s1.cancel()
      s2.cancel()
    }
  }
}

public func && <Left: FetchCondition, Right: FetchCondition>(
  _ left: Left,
  _ right: Right
) -> AndCondition<Left, Right> {
  AndCondition(left: left, right: right)
}
