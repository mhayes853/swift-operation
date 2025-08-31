extension ModifiedOperation: MutationRequest where Operation: MutationRequest {
  public func mutate(
    isolation: isolated (any Actor)?,
    with arguments: Operation.Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.MutateValue, Operation.MutateFailure>
  ) async throws(Operation.MutateFailure) -> Operation.MutateValue {
    try await self.operation.mutate(
      isolation: isolation,
      with: arguments,
      in: context,
      with: continuation
    )
  }
}
