extension QueryRequest {
  public func suspend(
    on condition: some FetchCondition
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(SuspendModifier(condition: condition))
  }
}

private struct SuspendModifier<Query: QueryRequest, Condition: FetchCondition>: QueryModifier {
  let condition: Condition

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    guard !self.condition.isSatisfied(in: context) else {
      return try await query.fetch(in: context, with: continuation)
    }
    try await self.waitForTrue(in: context)
    return try await query.fetch(in: context, with: continuation)
  }

  private func waitForTrue(in context: QueryContext) async throws {
    var subscription: QuerySubscription?
    let state = RecursiveLock<(didFinish: Bool, continuation: UnsafeContinuation<Void, any Error>?)>(
      (false, nil)
    )
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
