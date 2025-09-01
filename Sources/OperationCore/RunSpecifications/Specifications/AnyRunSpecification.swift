/// A concrete, type-erased ``FetchCondition``.
///
/// Use this condition in scenarios where you need to return a concrete condition instead of an
/// `any FetchConditon`, but still need to return 1 of many condition types.
public struct AnySendableRunSpecification: OperationRunSpecification, Sendable {
  /// The base ``FetchCondition`` as an existential.
  public let base: any OperationRunSpecification & Sendable

  /// Type-erases `condition`.
  ///
  /// - Parameter condition: The underlying ``FetchCondition`` to erase.
  public init(_ condition: some OperationRunSpecification & Sendable) {
    self.base = condition
  }

  public func isSatisfied(in context: OperationContext) -> Bool {
    self.base.isSatisfied(in: context)
  }

  public func subscribe(
    in context: OperationContext,
    onChange: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    self.base.subscribe(in: context, onChange: onChange)
  }
}
