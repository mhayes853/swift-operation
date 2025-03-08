public struct StaticObserver: FetchConditionObserver {
  let isTrue: Bool

  public func isSatisfied(in context: QueryContext) -> Bool {
    isTrue
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    observer(self.isTrue)
    return .empty
  }
}

extension FetchConditionObserver where Self == StaticObserver {
  public static func `is`(_ value: Bool) -> Self {
    Self(isTrue: value)
  }

  public static var `true`: Self {
    Self(isTrue: true)
  }

  public static var `false`: Self {
    Self(isTrue: false)
  }
}
