extension ModifiedQuery: MutationRequest where Query: MutationRequest {
  public func mutate(
    with arguments: Query.Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    try await self.query.mutate(with: arguments, in: context, with: continuation)
  }
}
