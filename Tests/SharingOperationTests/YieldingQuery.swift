import Operation

struct WithTaskMegaYieldModifier<Query: QueryRequest>: QueryModifier {
  func fetch(
    in context: OperationContext,
    using query: Query,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    await Task.megaYield()
    return try await query.fetch(in: context, with: continuation)
  }
}

extension QueryRequest {
  func withTaskMegaYield() -> ModifiedQuery<Self, WithTaskMegaYieldModifier<Self>> {
    self.modifier(WithTaskMegaYieldModifier())
  }
}
