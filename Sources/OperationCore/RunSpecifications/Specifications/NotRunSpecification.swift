// MARK: - NotCondition

/// A ``FetchCondition`` that negates the value of a base condition by applying a boolean NOT
/// operator to the base condition.
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
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> OperationSubscription {
    self.base.subscribe(in: context) { observer(!$0) }
  }
}

// MARK: - Not Operator

/// Applies a boolean NOT operation on the specified ``FetchCondition``.
///
/// - Parameter base: The condition to negate.
/// - Returns: A ``NotCondition``.
@inlinable
public prefix func ! <Base: OperationRunSpecification>(
  _ base: Base
) -> NotRunSpecification<Base> {
  NotRunSpecification(base: base)
}
