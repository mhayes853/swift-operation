// MARK: - RetryModifier

extension QueryRequest {
  public func retry(
    limit: Int,
    backoff: QueryBackoffFunction? = nil,
    delayer: (any QueryDelayer)? = nil
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(RetryModifier(limit: limit, backoff: backoff, delayer: delayer))
  }
}

private struct RetryModifier<Query: QueryRequest>: QueryModifier {
  let limit: Int
  let backoff: QueryBackoffFunction?
  let delayer: (any QueryDelayer)?

  func setup(context: inout QueryContext, using query: Query) {
    context.queryMaxRetries = self.limit
    query.setup(context: &context)
  }

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    var context = context
    let backoff = self.backoff ?? context.queryBackoffFunction
    let delayer = self.delayer ?? context.queryDelayer
    for index in 0..<context.queryMaxRetries {
      do {
        context.queryRetryIndex = index
        return try await query.fetch(in: context, with: continuation)
      } catch {
        try await delayer.delay(for: backoff(index + 1))
      }
    }
    context.queryRetryIndex = context.queryMaxRetries
    return try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var queryRetryIndex: Int {
    get { self[RetryIndexKey.self] }
    set { self[RetryIndexKey.self] = newValue }
  }

  private enum RetryIndexKey: Key {
    static let defaultValue = 0
  }

  public var queryMaxRetries: Int {
    get { self[MaxRetriesKey.self] }
    set { self[MaxRetriesKey.self] = newValue }
  }

  private enum MaxRetriesKey: Key {
    static let defaultValue = 0
  }
}
