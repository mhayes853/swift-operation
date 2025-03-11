// MARK: - QueryProtocol

extension QueryProtocol {
  public func enableAutomaticFetching(
    when condition: some FetchConditionObserver
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(EnableAutomaticFetchingModifier(condition: condition))
  }
}

private struct EnableAutomaticFetchingModifier<Query: QueryProtocol>: QueryModifier {
  let condition: any FetchConditionObserver

  func _setup(context: inout QueryContext, using query: Query) {
    context.enableAutomaticFetchingCondition = self.condition
    query._setup(context: &context)
  }

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    try await query.fetch(in: context)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var enableAutomaticFetchingCondition: any FetchConditionObserver {
    get { self[EnableAutomaticFetchingKey.self] }
    set { self[EnableAutomaticFetchingKey.self] = newValue }
  }

  private enum EnableAutomaticFetchingKey: Key {
    static var defaultValue: any FetchConditionObserver { .always(true) }
  }
}
