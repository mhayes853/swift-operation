// MARK: - QueryCacheValue

public enum QueryCacheValue<Value: Sendable>: Sendable {
  case stale(Value)
  case fresh(Value)
}

// MARK: - QueryCache

public protocol QueryCache<Query> {
  associatedtype Query: QueryProtocol

  func value(
    for query: Query,
    in context: QueryContext
  ) async throws -> QueryCacheValue<Query.State.StatusValue>?

  func saveValue(
    _ value: Query.State.StatusValue,
    for query: Query,
    in context: QueryContext
  ) async throws

  func removeValue(for query: Query, in context: QueryContext) async throws
}
