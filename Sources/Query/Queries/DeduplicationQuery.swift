extension QueryRequest {
  public func deduplicated() -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(
      DeduplicationModifier { i1, i2 in
        if let query = self as? any InfiniteQueryRequest {
          return removeDuplicateInfiniteQueries(i1, i2, using: query)
        } else {
          return true
        }
      }
    )
  }

  public func deduplicated(
    by removeDuplicates: @escaping @Sendable (QueryContext, QueryContext) -> Bool
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(DeduplicationModifier(removeDuplicates: removeDuplicates))
  }
}

private final actor DeduplicationModifier<Query: QueryRequest>: QueryModifier {
  private let removeDuplicates: @Sendable (QueryContext, QueryContext) -> Bool

  private var idCounter = 0
  private var entries = [(id: Int, context: QueryContext, task: Task<Query.Value, any Error>)]()

  init(removeDuplicates: @escaping @Sendable (QueryContext, QueryContext) -> Bool) {
    self.removeDuplicates = removeDuplicates
  }

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    if let entry = self.entries.first(where: { self.removeDuplicates($0.context, context) }) {
      return try await entry.task.cancellableValue
    } else {
      defer { self.idCounter += 1 }
      let id = self.idCounter
      let task = Task {
        defer { self.entries.removeAll { $0.id == id } }
        return try await query.fetch(in: context, with: continuation)
      }
      self.entries.append((id, context, task))
      return try await task.cancellableValue
    }
  }
}
