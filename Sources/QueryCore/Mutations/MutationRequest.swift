// MARK: - MutationRequest

public protocol MutationRequest<Arguments, Value>: QueryRequest
where State == MutationState<Arguments, Value> {
  associatedtype Arguments: Sendable

  func mutate(
    with arguments: Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}

// MARK: - Fetch

extension MutationRequest {
  public func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    guard let args = context.mutationArgs(as: Arguments.self) else {
      throw MutationNoArgumentsError()
    }
    return try await self.mutate(with: args, in: context, with: continuation)
  }
}

private struct MutationNoArgumentsError: Error {}

// MARK: - Void Mutate

extension MutationRequest where Arguments == Void {
  public func mutate(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    try await self.mutate(with: (), in: context, with: continuation)
  }
}
