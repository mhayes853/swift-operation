extension ModifiedOperation: MutationRequest where Operation: MutationRequest {
  public func mutate(
    with arguments: Operation.Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.ReturnValue>
  ) async throws -> Operation.ReturnValue {
    try await self.operation.mutate(with: arguments, in: context, with: continuation)
  }
}
