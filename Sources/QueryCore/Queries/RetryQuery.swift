// MARK: - RetryModifier

extension QueryProtocol {
  public func retry(
    limit: Int,
    backoff: QueryBackoffFunction?
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(RetryModifier(limit: limit, backoff: backoff))
  }
}

private struct RetryModifier<Query: QueryProtocol>: QueryModifier {
  let limit: Int
  let backoff: QueryBackoffFunction?

  func setup(context: inout QueryContext, using query: Query) {
    context.maxRetryIndex = self.limit
    query.setup(context: &context)
  }

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    var context = context
    for index in 0..<self.limit {
      do {
        context.retryIndex = index
        return try await query.fetch(in: context)
      } catch {
        continue
      }
    }
    context.retryIndex = self.limit
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

  public var maxRetryIndex: Int {
    get { self[MaxRetryIndexKey.self] }
    set { self[MaxRetryIndexKey.self] = newValue }
  }

  private enum MaxRetryIndexKey: Key {
    static let defaultValue = 0
  }
}
