// MARK: - MutationProtocol

public protocol MutationProtocol<Arguments>: QueryProtocol
where State == MutationState<Arguments, Value> {
  associatedtype Arguments: Sendable

  func mutate(
    with arguments: Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}

extension MutationProtocol {
  public func setup(context: inout QueryContext) {
    context.enableAutomaticFetchingCondition = .always(false)
  }

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

// MARK: - MutationStore

extension MutationProtocol {
  public func currentMutationStore(in context: QueryContext) -> MutationStoreFor<Self>? {
    self.currentQueryStore(in: context).map { MutationStore(store: $0) }
  }
}
