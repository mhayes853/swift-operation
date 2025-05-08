extension QueryRequest {
  /// Deduplicates fetches to this query.
  ///
  /// When 2 fetches on this query occur at the same time, the second fetch will not invoke this
  /// query, but rather wait for the result of the first fetch.
  ///
  /// - Returns: A ``ModifiedQuery``.
  public func deduplicated() -> ModifiedQuery<Self, _DeduplicationModifier<Self>> {
    self.modifier(
      _DeduplicationModifier { i1, i2 in
        if let query = self as? any InfiniteQueryRequest {
          return removeDuplicateInfiniteQueries(i1, i2, using: query)
        } else {
          return true
        }
      }
    )
  }

  /// Deduplicates fetches to this query based on a predicate.
  ///
  /// When 2 fetches on this query occur at the same time, the second fetch will not invoke this
  /// query, but rather wait for the result of the first fetch.
  ///
  /// - Parameter removeDuplicates: A predicate to distinguish duplicate fetch attempts.
  /// - Returns: A ``ModifiedQuery``.
  public func deduplicated(
    by removeDuplicates: @escaping @Sendable (QueryContext, QueryContext) -> Bool
  ) -> ModifiedQuery<Self, _DeduplicationModifier<Self>> {
    self.modifier(_DeduplicationModifier(removeDuplicates: removeDuplicates))
  }
}

public struct _DeduplicationModifier<Query: QueryRequest>: QueryModifier {
  private let storage: Storage

  init(removeDuplicates: @escaping @Sendable (QueryContext, QueryContext) -> Bool) {
    self.storage = Storage(removeDuplicates: removeDuplicates)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    if let task = await self.storage.task(for: context) {
      return try await task.cancellableValue
    } else {
      return try await self.storage.fetch(query: query, in: context, with: continuation)
    }
  }
}

extension _DeduplicationModifier {
  private final actor Storage {
    private let removeDuplicates: @Sendable (QueryContext, QueryContext) -> Bool

    private var idCounter = 0
    private var entries = [(id: Int, context: QueryContext, task: Task<Query.Value, any Error>)]()

    init(removeDuplicates: @escaping @Sendable (QueryContext, QueryContext) -> Bool) {
      self.removeDuplicates = removeDuplicates
    }

    func task(for context: QueryContext) -> Task<Query.Value, any Error>? {
      self.entries.first(where: { self.removeDuplicates($0.context, context) })?.task
    }

    func fetch(
      query: Query,
      in context: QueryContext,
      with continuation: QueryContinuation<Query.Value>
    ) async throws -> Query.Value {
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
