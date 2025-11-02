public struct AnyOperation<Value, Failure: Error>: OperationRequest {
  public let base: any OperationRequest<Value, Failure>

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
