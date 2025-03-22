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
    by removeDuplicates: @escaping @Sendable (QueryTaskInfo, QueryTaskInfo) -> Bool
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(DeduplicationModifier(removeDuplicates: removeDuplicates))
  }
}

private final actor DeduplicationModifier<Query: QueryRequest>: QueryModifier {
  private let removeDuplicates: @Sendable (QueryTaskInfo, QueryTaskInfo) -> Bool

  private var entries = [
    QueryTaskIdentifier: (info: QueryTaskInfo, task: Task<Query.Value, any Error>)
  ]()

  init(removeDuplicates: @escaping @Sendable (QueryTaskInfo, QueryTaskInfo) -> Bool) {
    self.removeDuplicates = removeDuplicates
  }

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    guard let taskInfo = context.queryRunningTaskInfo else {
      return try await query.fetch(in: context, with: continuation)
    }
    let entry = self.entries.first { self.removeDuplicates($0.value.info, taskInfo) }?.value
    if let entry {
      return try await entry.task.value
    } else {
      let task = Task {
        defer { self.entries[taskInfo.id] = nil }
        return try await query.fetch(in: context, with: continuation)
      }
      self.entries[taskInfo.id] = (taskInfo, task)
      return try await task.value
    }
  }
}
