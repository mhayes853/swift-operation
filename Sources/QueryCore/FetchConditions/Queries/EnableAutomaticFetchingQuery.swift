// MARK: - QueryProtocol

extension QueryRequest {
  public func enableAutomaticFetching(
    when condition: some FetchCondition
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(EnableAutomaticFetchingModifier(condition: condition))
  }
}

private struct EnableAutomaticFetchingModifier<Query: QueryRequest>: QueryModifier {
  let condition: any FetchCondition

  func setup(context: inout QueryContext, using query: Query) {
    context.enableAutomaticFetchingCondition = self.condition
    query.setup(context: &context)
  }

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var enableAutomaticFetchingCondition: any FetchCondition {
    get { self[EnableAutomaticFetchingKey.self] }
    set { self[EnableAutomaticFetchingKey.self] = newValue }
  }

  private enum EnableAutomaticFetchingKey: Key {
    static var defaultValue: any FetchCondition { .always(true) }
  }
}
