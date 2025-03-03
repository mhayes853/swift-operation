// MARK: - QueryProtocol

extension QueryProtocol {
  public func enableAutomaticFetching(
    when condition: EnableStoreAutomaticFetchingCondition
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(EnableAutomaticFetchingModifier(condition: condition))
  }
}

private struct EnableAutomaticFetchingModifier<Query: QueryProtocol>: QueryModifier {
  let condition: EnableStoreAutomaticFetchingCondition

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
  public var enableAutomaticFetchingCondition: EnableStoreAutomaticFetchingCondition {
    get { self[EnableAutomaticFetchingKey.self] }
    set { self[EnableAutomaticFetchingKey.self] = newValue }
  }

  private enum EnableAutomaticFetchingKey: Key {
    static let defaultValue = EnableStoreAutomaticFetchingCondition.firstSubscribedTo
  }
}
