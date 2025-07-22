// MARK: - RetryModifier

extension QueryRequest {
  /// Applies a retry strategy to this query.
  ///
  /// - Parameters:
  ///   - limit: The maximum number of retries.
  /// - Returns: A ``ModifiedQuery``.
  public func retry(limit: Int) -> ModifiedQuery<Self, _RetryModifier<Self>> {
    self.modifier(_RetryModifier(limit: limit))
  }
}

public struct _RetryModifier<Query: QueryRequest>: QueryModifier {
  let limit: Int

  public func setup(context: inout QueryContext, using query: Query) {
    context.queryMaxRetries = self.limit
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    var context = context
    for index in 0..<context.queryMaxRetries {
      try Task.checkCancellation()
      do {
        context.queryRetryIndex = index
        return try await query.fetch(in: context, with: continuation)
      } catch {
        try await context.queryDelayer.delay(for: context.queryBackoffFunction(index + 1))
      }
    }
    try Task.checkCancellation()
    context.queryRetryIndex = context.queryMaxRetries
    return try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The current retry attempt for a query.
  ///
  /// This value starts at 0, but increments every time ``QueryRequest/retry(limit:)``
  /// retries a query.
  public var queryRetryIndex: Int {
    get { self[RetryIndexKey.self] }
    set { self[RetryIndexKey.self] = newValue }
  }

  private enum RetryIndexKey: Key {
    static let defaultValue = 0
  }

  /// The maximum number of retries for a query.
  ///
  /// The default value of this context property is 0. However, using
  /// ``QueryRequest/retry(limit:)`` will set this value to the `limit` parameter.
  public var queryMaxRetries: Int {
    get { self[MaxRetriesKey.self] }
    set { self[MaxRetriesKey.self] = newValue }
  }

  private enum MaxRetriesKey: Key {
    static let defaultValue = 0
  }

  /// Whether or not the query is on its last retry attempt.
  public var isLastRetryAttempt: Bool {
    self.queryRetryIndex == self.queryMaxRetries
  }
}
