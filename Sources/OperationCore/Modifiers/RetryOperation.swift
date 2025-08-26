// MARK: - RetryModifier

extension OperationRequest {
  /// Applies a retry strategy to this query.
  ///
  /// - Parameters:
  ///   - limit: The maximum number of retries.
  /// - Returns: A ``ModifiedOperation``.
  public func retry(limit: Int) -> ModifiedOperation<Self, _RetryModifier<Self>> {
    self.modifier(_RetryModifier(limit: limit))
  }
}

public struct _RetryModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let limit: Int

  public func setup(context: inout OperationContext, using operation: Operation) {
    context.operationMaxRetries = self.limit
    operation.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value>
  ) async throws -> Operation.Value {
    var context = context
    for index in 0..<context.operationMaxRetries {
      try Task.checkCancellation()
      do {
        context.operationRetryIndex = index
        return try await operation.run(isolation: isolation, in: context, with: continuation)
      } catch {
        try await context.operationDelayer.delay(for: context.operationBackoffFunction(index + 1))
      }
    }
    try Task.checkCancellation()
    context.operationRetryIndex = context.operationMaxRetries
    return try await operation.run(isolation: isolation, in: context, with: continuation)
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
