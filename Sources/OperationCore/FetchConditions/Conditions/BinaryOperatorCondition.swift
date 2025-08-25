// MARK: - BinaryOperatorConditions

/// A ``FetchCondition`` that applies a binary boolean operator between 2 conditions.
public struct BinaryOperatorCondition<
  Left: FetchCondition,
  Right: FetchCondition,
  Operator: _BinaryFetchConditionOperator
> {
  fileprivate let left: Left
  fileprivate let right: Right
  fileprivate let op: Operator
}

// MARK: - FetchCondition Conformance

extension BinaryOperatorCondition: FetchCondition {
  public func isSatisfied(in context: OperationContext) -> Bool {
    self.op.evaluate(self.left.isSatisfied(in: context), self.right.isSatisfied(in: context))
  }

  public func subscribe(
    in context: OperationContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> OperationSubscription {
    // TODO: - Flatten nested BinaryOperatorConditions in the lock to improve performance.
    let state = Lock(
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
    return .combined(s1, s2)
  }
}

// MARK: - Operators

/// Applies a boolean AND operation between the 2 specified ``FetchCondition``s.
///
/// - Parameters:
///   - left: The left hand side condition.
///   - right: The right hand side condition.
/// - Returns: A ``BinaryOperatorCondition`` that applies a boolean AND.
public func && <Left: FetchCondition, Right: FetchCondition>(
  _ left: Left,
  _ right: Right
) -> BinaryOperatorCondition<Left, Right, _AndOperator> {
  BinaryOperatorCondition(left: left, right: right, op: _AndOperator())
}

/// Applies a boolean OR operation between the 2 specified ``FetchCondition``s.
///
/// - Parameters:
///   - left: The left hand side condition.
///   - right: The right hand side condition.
/// - Returns: A ``BinaryOperatorCondition`` that applies a boolean OR.
public func || <Left: FetchCondition, Right: FetchCondition>(
  _ left: Left,
  _ right: Right
) -> BinaryOperatorCondition<Left, Right, _OrOperator> {
  BinaryOperatorCondition(left: left, right: right, op: _OrOperator())
}

// MARK: - Operator

public protocol _BinaryFetchConditionOperator: Sendable {
  func evaluate(_ left: Bool, _ right: Bool) -> Bool
}

public struct _AndOperator: _BinaryFetchConditionOperator {
  @inlinable
  public func evaluate(_ left: Bool, _ right: Bool) -> Bool {
    left && right
  }
}

public struct _OrOperator: _BinaryFetchConditionOperator {
  @inlinable
  public func evaluate(_ left: Bool, _ right: Bool) -> Bool {
    left || right
  }
}
