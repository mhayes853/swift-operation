extension ModifiedOperation: MutationRequest where Operation: MutationRequest {
  public func mutate(
    isolation: isolated (any Actor)?,
    with arguments: Operation.Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.ReturnValue>
  ) async throws -> Operation.ReturnValue {
    try await self.operation.mutate(
      isolation: isolation,
      with: arguments,
      in: context,
      with: continuation
    )
  }
}
