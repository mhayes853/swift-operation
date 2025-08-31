/// A ``FetchCondition`` that returns a static value.
public struct AlwaysRunSpecification: OperationRunSpecification, Sendable {
  @usableFromInline
  let isTrue: Bool

  @usableFromInline
  let shouldEmitInitialValue: Bool

  @inlinable
  public init(isTrue: Bool, shouldEmitInitialValue: Bool) {
    self.isTrue = isTrue
    self.shouldEmitInitialValue = shouldEmitInitialValue
  }

  @inlinable
  public func isSatisfied(in context: OperationContext) -> Bool {
    isTrue
  }

  @inlinable
  public func subscribe(
    in context: OperationContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> OperationSubscription {
    if self.shouldEmitInitialValue {
      observer(self.isTrue)
    }
    return .empty
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
  public static func always(_ value: Bool, shouldEmitInitialValue: Bool = false) -> Self {
    Self(isTrue: value, shouldEmitInitialValue: shouldEmitInitialValue)
  }
}
