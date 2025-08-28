extension ModifiedOperation: QueryRequest where Operation: QueryRequest {
  public func fetch(
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.ReturnValue>
  ) async throws -> Operation.ReturnValue {
    try await self.operation.fetch(in: context, with: continuation)
  }
}
