/// A ``FetchCondition`` that returns a static value.
public struct AlwaysCondition: FetchCondition {
  @usableFromInline
  let isTrue: Bool

  @usableFromInline
  let shouldEmitInitialValue: Bool

  @usableFromInline
  init(isTrue: Bool, shouldEmitInitialValue: Bool) {
    self.isTrue = isTrue
    self.shouldEmitInitialValue = shouldEmitInitialValue
  }

  @inlinable
  public func isSatisfied(in context: QueryContext) -> Bool {
    isTrue
  }

  @inlinable
  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    if self.shouldEmitInitialValue {
      observer(self.isTrue)
    }
    return .empty
  }
}

extension FetchCondition where Self == AlwaysCondition {
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
