/// An ``OperationRunSpecification`` that returns a static value.
public struct AlwaysRunSpecification: OperationRunSpecification, Sendable {
  @usableFromInline
  let isTrue: Bool

  @inlinable
  public init(isTrue: Bool) {
    self.isTrue = isTrue
  }

  @inlinable
  public func isSatisfied(in context: OperationContext) -> Bool {
    self.isTrue
  }

  @inlinable
  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    .empty
  }
}

extension OperationRunSpecification where Self == AlwaysRunSpecification {
  /// An ``OperationRunSpecification`` that returns a static value.
  ///
  /// - Parameter isTrue: The static value to always return from the condition.
  /// - Returns: An ``AlwaysRunSpecification``.
  @inlinable
  public static func always(_ isTrue: Bool) -> Self {
    Self(isTrue: isTrue)
  }
}
