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
    await self.condition.waitForTrue(in: context)
    return try await query.fetch(in: context)
  }
}

extension FetchCondition {
  fileprivate func waitForTrue(in context: QueryContext) async {
    var subscription: QuerySubscription?
    await withUnsafeContinuation { continuation in
      subscription = self.subscribe(in: context) {
        if $0 {
          continuation.resume()
        }
      }
    }
    _ = subscription
  }
}
