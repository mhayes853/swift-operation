public struct BinaryOperatorCondition<Left: FetchCondition, Right: FetchCondition> {
  let left: Left
  let right: Right
  let op: Operator
}

enum Operator {
  case and
  case or
}

extension BinaryOperatorCondition: FetchCondition {
  public func isSatisfied(in context: QueryContext) -> Bool {
    switch self.op {
    case .or: self.left.isSatisfied(in: context) || self.right.isSatisfied(in: context)
    case .and: self.left.isSatisfied(in: context) && self.right.isSatisfied(in: context)
    }
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
        switch self.op {
        case .or: observer($0.left || $0.right)
        case .and: observer($0.left && $0.right)
        }
      }
    }
    let s2 = self.right.subscribe(in: context) { value in
      state.withLock {
        $0.right = value
        switch self.op {
        case .or: observer($0.left || $0.right)
        case .and: observer($0.left && $0.right)
        }
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
) -> BinaryOperatorCondition<Left, Right> {
  BinaryOperatorCondition(left: left, right: right, op: .and)
}

public func || <Left: FetchCondition, Right: FetchCondition>(
  _ left: Left,
  _ right: Right
) -> BinaryOperatorCondition<Left, Right> {
  BinaryOperatorCondition(left: left, right: right, op: .or)
}
