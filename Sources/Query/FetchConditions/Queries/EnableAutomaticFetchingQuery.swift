// MARK: - QueryProtocol

extension QueryRequest {
  public func enableAutomaticFetching<Condition: FetchCondition>(
    onlyWhen condition: Condition
  ) -> ModifiedQuery<Self, EnableAutomaticFetchingModifier<Self, Condition>> {
    self.modifier(EnableAutomaticFetchingModifier(condition: condition))
  }
}

public struct EnableAutomaticFetchingModifier<
  Query: QueryRequest,
  Condition: FetchCondition
>: QueryModifier {
  let condition: any FetchCondition

  public func setup(context: inout QueryContext, using query: Query) {
    context.enableAutomaticFetchingCondition = self.condition
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

// MARK: - QueryContext

extension QueryContext {
  public var enableAutomaticFetchingCondition: any FetchCondition {
    get { self[EnableAutomaticFetchingKey.self] }
    set { self[EnableAutomaticFetchingKey.self] = newValue }
  }

  private enum EnableAutomaticFetchingKey: Key {
    static var defaultValue: any FetchCondition { .always(false) }
  }
}
