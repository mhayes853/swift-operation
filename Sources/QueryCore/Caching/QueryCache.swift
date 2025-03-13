public protocol QueryCache<Value> {
  associatedtype Value: Sendable

  func value(
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws -> QueryCacheValue<Value>?

  func save(
    _ value: Value,
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws

  func removeValue(for query: some QueryProtocol<Value>, in context: QueryContext) async throws
}
