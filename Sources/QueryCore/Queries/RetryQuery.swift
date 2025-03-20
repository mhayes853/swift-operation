// MARK: - RetryModifier

extension QueryProtocol {
  public func retry(
    limit: Int,
    backoff: QueryBackoffFunction? = nil,
    delayer: (any QueryDelayer)? = nil
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(RetryModifier(limit: limit, backoff: backoff, delayer: delayer))
  }
}

private struct RetryModifier<Query: QueryProtocol>: QueryModifier {
  let limit: Int
  let backoff: QueryBackoffFunction?
  let delayer: (any QueryDelayer)?

  func setup(context: inout QueryContext, using query: Query) {
    context.maxRetries = self.limit
    query.setup(context: &context)
  }

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    var context = context
    for index in 0..<context.maxRetries {
      do {
        context.retryIndex = index
        return try await query.fetch(in: context)
      } catch {
        continue
      }
    }
    context.retryIndex = context.maxRetries
    return try await query.fetch(in: context)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var retryIndex: Int {
    get { self[RetryIndexKey.self] }
    set { self[RetryIndexKey.self] = newValue }
  }

  private enum RetryIndexKey: Key {
    static let defaultValue = 0
  }

  public var maxRetries: Int {
    get { self[MaxRetryIndexKey.self] }
    set { self[MaxRetryIndexKey.self] = newValue }
  }

  private enum MaxRetryIndexKey: Key {
    static let defaultValue = 0
  }
}
