// MARK: - NotCondition

/// An ``OperationRunSpecification`` that negates the satisfaction of a base condition by applying
/// a boolean NOT operator to the base specification.
public struct NotRunSpecification<Base: OperationRunSpecification>: OperationRunSpecification {
  @usableFromInline
  let base: Base

  @usableFromInline
  init(base: Base) {
    self.base = base
  }

  @inlinable
  public func isSatisfied(in context: OperationContext) -> Bool {
    !self.base.isSatisfied(in: context)
  }

  @inlinable
  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.base.subscribe(in: context, onChange: onChange)
  }
}

extension NotRunSpecification: Sendable where Base: Sendable {}

// MARK: - Not Operator

/// Applies a boolean NOT operation on the satisfaction of the specified
/// ``OperationRunSpecification``.
///
/// - Parameter base: The specification to negate.
/// - Returns: A ``NotRunSpecification``.
@inlinable
public prefix func ! <Base: OperationRunSpecification>(
  _ base: Base
) -> NotRunSpecification<Base> {
  NotRunSpecification(base: base)
}
