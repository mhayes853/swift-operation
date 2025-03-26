// MARK: - BinaryOperatorConditions

public struct BinaryOperatorCondition<Left: FetchCondition, Right: FetchCondition> {
  fileprivate let left: Left
  fileprivate let right: Right
  fileprivate let op: Operator
}

// MARK: - FetchCondition Conformance

extension BinaryOperatorCondition: FetchCondition {
  public func isSatisfied(in context: QueryContext) -> Bool {
    self.op.evaluate(self.left.isSatisfied(in: context), self.right.isSatisfied(in: context))
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    // TODO: - Flatten nested BinaryOperatorConditions in the lock to improve performance.
    let state = RecursiveLock(
      (left: self.left.isSatisfied(in: context), right: self.right.isSatisfied(in: context))
    )
    let s1 = self.left.subscribe(in: context) { value in
      state.withLock {
        $0.left = value
        observer(self.op.evaluate($0.left, $0.right))
      }
    }
    let s2 = self.right.subscribe(in: context) { value in
      state.withLock {
        $0.right = value
        observer(self.op.evaluate($0.left, $0.right))
      }
    }
    return QuerySubscription {
      s1.cancel()
      s2.cancel()
    }
  }
}

// MARK: - Operators

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

// MARK: - Operator

private enum Operator {
  case and
  case or
}

extension Operator {
  func evaluate(_ left: Bool, _ right: Bool) -> Bool {
    switch self {
    case .and: left && right
    case .or: left || right
    }
  }
}
