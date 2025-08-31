/// A ``FetchCondition`` that returns a static value.
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
  /// A ``FetchCondition`` that returns a static value.
  ///
  /// - Parameters:
  ///   - value: The static value to always return from the condition.
  ///   - shouldEmitInitialValue: Whether or not the condition should emit `value` when intially subscribed to.
  /// - Returns: An ``AlwaysCondition``.
  @inlinable
  public static func always(_ value: Bool) -> Self {
    Self(isTrue: value)
  }
}
