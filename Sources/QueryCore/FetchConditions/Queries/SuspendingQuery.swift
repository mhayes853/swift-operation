extension QueryProtocol {
  public func suspend(
    on condition: some FetchCondition
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(SuspendModifier(condition: condition))
  }
}

private struct SuspendModifier<Query: QueryProtocol, Condition: FetchCondition>: QueryModifier {
  let condition: Condition

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    guard !self.condition.isSatisfied(in: context) else {
      return try await query.fetch(in: context)
    }
    await self.waitForTrue(in: context)
    return try await query.fetch(in: context)
  }

  private func waitForTrue(in context: QueryContext) async {
    var subscription: QuerySubscription?
    let didFinish = Lock(false)
    await withUnsafeContinuation { continuation in
      subscription = self.condition.subscribe(in: context) { value in
        didFinish.withLock { didFinish in
          if value && !didFinish {
            continuation.resume()
            didFinish = true
          }
        }
      }
    }
    _ = subscription
  }
}
