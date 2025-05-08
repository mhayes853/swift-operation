// MARK: - RetryModifier

extension QueryRequest {
  /// Applies a retry strategy to this query.
  ///
  /// - Parameters:
  ///   - limit: The maximum number of retries.
  ///   - backoff: The ``QueryBackoffFunction`` to use for delay calculation (defaults to ``QueryContext/queryBackoffFunction``).
  ///   - delayer: The ``QueryDelayer`` to use for delaying retry attempts (defaults to ``QueryContext/queryDelayer``)
  /// - Returns: A ``ModifiedQuery``.
  public func retry(
    limit: Int,
    backoff: QueryBackoffFunction? = nil,
    delayer: (any QueryDelayer)? = nil
  ) -> ModifiedQuery<Self, _RetryModifier<Self>> {
    self.modifier(_RetryModifier(limit: limit, backoff: backoff, delayer: delayer))
  }
}

public struct _RetryModifier<Query: QueryRequest>: QueryModifier {
  let limit: Int
  let backoff: QueryBackoffFunction?
  let delayer: (any QueryDelayer)?

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
    let backoff = self.backoff ?? context.queryBackoffFunction
    let delayer = self.delayer ?? context.queryDelayer
    for index in 0..<context.queryMaxRetries {
      try Task.checkCancellation()
      do {
        context.queryRetryIndex = index
        return try await query.fetch(in: context, with: continuation)
      } catch {
        try await delayer.delay(for: backoff(index + 1))
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
  /// This value starts at 0, but increments every time ``QueryRequest/retry(limit:backoff:delayer:)``
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
  /// ``QueryRequest/retry(limit:backoff:delayer:)`` will set this value to the `limit` parameter.
  public var queryMaxRetries: Int {
    get { self[MaxRetriesKey.self] }
    set { self[MaxRetriesKey.self] = newValue }
  }

  private enum MaxRetriesKey: Key {
    static let defaultValue = 0
  }
}
