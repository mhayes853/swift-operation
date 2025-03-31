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
  @inlinable
  public static func always(_ value: Bool, shouldEmitInitialValue: Bool = false) -> Self {
    Self(isTrue: value, shouldEmitInitialValue: shouldEmitInitialValue)
  }
}
