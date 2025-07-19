/// A concrete, type-erased ``FetchCondition``.
///
/// Use this condition in scenarios where you need to return a concrete condition instead of an
/// `any FetchConditon`, but still need to return 1 of many condition types.
public struct AnyFetchCondition: FetchCondition {
  /// The base ``FetchCondition`` as an existential.
  public let base: any FetchCondition

  /// Type-erases `condition`.
  ///
  /// - Parameter condition: The underlying ``FetchCondition`` to erase.
  public init(_ condition: some FetchCondition) {
    self.base = condition
  }

  public func isSatisfied(in context: QueryContext) -> Bool {
    self.base.isSatisfied(in: context)
  }

  public func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    self.base.subscribe(in: context, observer)
  }
}
