extension ModifiedQuery: MutationRequest where Query: MutationRequest {
  public func mutate(
    with arguments: Query.Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Query.ReturnValue>
  ) async throws -> Query.ReturnValue {
    try await self.query.mutate(with: arguments, in: context, with: continuation)
  }
}
