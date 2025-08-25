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

  public func setup(context: inout OperationContext, using query: Query) {
    context.operationMaxRetries = self.limit
    query.setup(context: &context)
  }

  public func fetch(
    in context: OperationContext,
    using query: Query,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    var context = context
    for index in 0..<context.operationMaxRetries {
      try Task.checkCancellation()
      do {
        context.operationRetryIndex = index
        return try await query.fetch(in: context, with: continuation)
      } catch {
        try await context.queryDelayer.delay(for: context.operationBackoffFunction(index + 1))
      }
    }
    try Task.checkCancellation()
    context.operationRetryIndex = context.operationMaxRetries
    return try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current retry attempt for a query.
  ///
  /// This value starts at 0, but increments every time ``QueryRequest/retry(limit:)``
  /// retries a query. An index value of 0 indicates that the query is being fetched for the first
  /// time, and has not yet been retried.
  public var operationRetryIndex: Int {
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
  public var operationMaxRetries: Int {
    get { self[MaxRetriesKey.self] }
    set { self[MaxRetriesKey.self] = newValue }
  }

  private enum MaxRetriesKey: Key {
    static let defaultValue = 0
  }

  /// Whether or not the query is on its last retry attempt.
  public var isLastRetryAttempt: Bool {
    self.operationRetryIndex == self.operationMaxRetries
  }

  /// Whether or not the query is on its first retry attempt.
  public var isFirstRetryAttempt: Bool {
    self.operationRetryIndex == 1
  }

  /// Whether or not the query is on its initial fetch attempt.
  ///
  /// This value is true when the query is being fetched for the first time, and has not been
  /// retried due to throwing an error. If you want to check if the query is being retried for
  /// the first time, use ``isFirstRetryAttempt``.
  public var isFirstFetchAttempt: Bool {
    self.operationRetryIndex == 0
  }
}
