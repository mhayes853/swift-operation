/// A concrete, type-erased ``OperationRunSpecification`` that is also Sendable.
public struct AnySendableRunSpecification: OperationRunSpecification, Sendable {
  /// The base ``OperationRunSpecification`` as an existential.
  public let base: any OperationRunSpecification & Sendable

  /// Type-erases `specification`.
  ///
  /// - Parameter specification: The underlying ``OperationRunSpecification`` to erase.
  public init(_ specification: some OperationRunSpecification & Sendable) {
    self.base = specification
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
