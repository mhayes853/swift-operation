/// A type-erased ``OperationRequest``.
public struct AnyOperation<Value, Failure: Error>: OperationRequest {
  /// An existential to the erased operation.
  public let base: any OperationRequest<Value, Failure>
  
  /// Type erases an ``OperationRequest``.
  ///
  /// - Parameter operation: The operation to erase.
  public init(_ operation: some OperationRequest<Value, Failure>) {
    self.base = operation
  }

  public func setup(context: inout OperationContext) {
    self.base.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, Failure>
  ) async throws(Failure) -> Value {
    try await self.base.run(isolation: isolation, in: context, with: continuation)
  }
}
