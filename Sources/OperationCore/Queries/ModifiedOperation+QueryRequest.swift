extension ModifiedOperation: QueryRequest where Operation: QueryRequest {
  public func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.FetchValue>
  ) async throws(Operation.Failure) -> Operation.FetchValue {
    try await self.operation.fetch(isolation: isolation, in: context, with: continuation)
  }
}
