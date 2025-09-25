// MARK: - BinaryOperatorConditions

/// An ``OperationRunSpecification`` that applies a binary boolean operator between the
/// satisfaction of 2 specifications.
public struct BinaryOperatorRunSpecification<
  Left: OperationRunSpecification,
  Right: OperationRunSpecification,
  Operator: _BinaryRunSpecificationOperator
>: OperationRunSpecification {
  let left: Left
  let right: Right
  let op: Operator

  public func isSatisfied(in context: OperationContext) -> Bool {
    self.op.evaluate(self.left.isSatisfied(in: context), self.right.isSatisfied(in: context))
  }

  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    let s1 = self.left.subscribe(in: context, onChange: onChange)
    let s2 = self.right.subscribe(in: context, onChange: onChange)
    return .combined(s1, s2)
  }
}

extension BinaryOperatorRunSpecification: Sendable
where Left: Sendable, Right: Sendable, Operator: Sendable {}

// MARK: - Operators

/// Applies a boolean AND operation between the satisfaction of the 2 specified
/// ``OperationRunSpecification``s.
///
/// - Parameters:
///   - left: The left hand side condition.
///   - right: The right hand side condition.
/// - Returns: A ``BinaryOperatorRunSpecification`` that applies a boolean AND.
public func && <Left: OperationRunSpecification, Right: OperationRunSpecification>(
  _ left: Left,
  _ right: Right
) -> BinaryOperatorRunSpecification<Left, Right, _AndRunSpecificationOperator> {
  BinaryOperatorRunSpecification(left: left, right: right, op: _AndRunSpecificationOperator())
}

/// Applies a boolean OR operation between the satisfaction of the 2 specified
/// ``OperationRunSpecification``s.
///
/// - Parameters:
///   - left: The left hand side condition.
///   - right: The right hand side condition.
/// - Returns: A ``BinaryOperatorRunSpecification`` that applies a boolean OR.
public func || <Left: OperationRunSpecification, Right: OperationRunSpecification>(
  _ left: Left,
  _ right: Right
) -> BinaryOperatorRunSpecification<Left, Right, _OrRunSpecificationOperator> {
  BinaryOperatorRunSpecification(left: left, right: right, op: _OrRunSpecificationOperator())
}

// MARK: - Operator

public protocol _BinaryRunSpecificationOperator {
  func evaluate(_ left: Bool, _ right: Bool) -> Bool
}

public struct _AndRunSpecificationOperator: _BinaryRunSpecificationOperator, Sendable {
  @inlinable
  public func evaluate(_ left: Bool, _ right: Bool) -> Bool {
    left && right
  }
}

public struct _OrRunSpecificationOperator: _BinaryRunSpecificationOperator, Sendable {
  @inlinable
  public func evaluate(_ left: Bool, _ right: Bool) -> Bool {
    left || right
  }
}
