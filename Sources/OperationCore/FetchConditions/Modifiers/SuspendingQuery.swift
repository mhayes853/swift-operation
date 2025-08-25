extension QueryRequest {
  /// Suspends this query's execution while the specified ``FetchCondition`` is false.
  ///
  /// When this query is suspended, it will remain in a perpetual loading state in your UI until
  /// the specified `condition` changes to true.
  ///
  /// > Note: If this query utilizes `URLSession` under the hood, and you wish to suspend it based on a
  /// > ``ConnectedCondition``, consider using [waitsForConnectivity](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/waitsforconnectivity)
  /// > instead.
  ///
  /// - Parameter condition: The ``FetchCondition`` to suspend on.
  /// - Returns: A ``ModifiedQuery``.
  public func suspend<Condition: FetchCondition>(
    on condition: Condition
  ) -> ModifiedQuery<Self, _SuspendModifier<Self, Condition>> {
    self.modifier(_SuspendModifier(condition: condition))
  }
}

public struct _SuspendModifier<Query: QueryRequest, Condition: FetchCondition>: QueryModifier {
  let condition: Condition

  public func fetch(
    in context: OperationContext,
    using query: Query,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    guard !self.condition.isSatisfied(in: context) else {
      return try await query.fetch(in: context, with: continuation)
    }
    try await self.waitForTrue(in: context)
    return try await query.fetch(in: context, with: continuation)
  }

  private func waitForTrue(in context: OperationContext) async throws {
    try Task.checkCancellation()
    var subscription: OperationSubscription?
    let state = Lock<
      (didFinish: Bool, continuation: UnsafeContinuation<Void, any Error>?)
    >((false, nil))
    try await withTaskCancellationHandler {
      try await withUnsafeThrowingContinuation { c in
        state.withLock { $0.continuation = c }
        subscription = self.condition.subscribe(in: context) { value in
          state.withLock { state in
            if value && !state.didFinish {
              state.continuation?.resume()
              state.didFinish = true
            }
          }
        }
      }
    } onCancel: {
      state.withLock { state in
        state.continuation?.resume(throwing: CancellationError())
        state.didFinish = true
      }
    }
    _ = subscription
  }
}
