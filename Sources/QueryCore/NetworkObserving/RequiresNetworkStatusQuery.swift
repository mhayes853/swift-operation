extension QueryRequest {
  public func runsOffline() -> ModifiedQuery<Self, _RequiresNetworkStatusModifier<Self>> {
    self.modifier(_RequiresNetworkStatusModifier(status: .disconnected))
  }

  public func requiresNetworkStatus(
    _ status: NetworkStatus
  ) -> ModifiedQuery<Self, _RequiresNetworkStatusModifier<Self>> {
    self.modifier(_RequiresNetworkStatusModifier(status: status))
  }
}

public struct _RequiresNetworkStatusModifier<Query: QueryRequest>: QueryModifier {
  let status: NetworkStatus

  public func setup(context: inout QueryContext, using query: Query) {
    context.satisfiedConnectionStatus = self.status
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}
