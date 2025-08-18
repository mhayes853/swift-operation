import Query

struct WithTaskMegaYieldModifier<Query: QueryRequest>: QueryModifier {
  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
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
