// MARK: - QueryCacheValue

public enum QueryCacheValue<Value: Sendable>: Sendable {
  case stale(Value)
  case fresh(Value)
}

// MARK: - QueryCache

public protocol QueryCache<Value> {
  associatedtype Value: Sendable

  func value(
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws -> QueryCacheValue<Value>?

  func saveValue(
    _ value: Value,
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws

  func removeValue(for query: some QueryProtocol<Value>, in context: QueryContext) async throws
}
