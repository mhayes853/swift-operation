import Operation

struct WithTaskMegaYieldModifier<Operation: OperationRequest>: OperationModifier {
  func fetch(
    in context: OperationContext,
    using query: Query,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    await Task.megaYield()
    return try await query.fetch(in: context, with: continuation)
  }
}

extension OperationRequest {
  func withTaskMegaYield() -> ModifiedOperation<Self, WithTaskMegaYieldModifier<Self>> {
    self.modifier(WithTaskMegaYieldModifier())
  }
}
