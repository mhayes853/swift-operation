// MARK: - QueryStore

public final class QueryStore<Value: Sendable>: Sendable {
  private let query: any QueryProtocol<Value>
  public let value: Value

  init<V>(query: some QueryProtocol<V>) where Value == V? {
    self.query = ToOptionalQuery(base: query)
    self.value = nil
  }

  init(query: DefaultQuery<some QueryProtocol<Value>>) {
    self.query = query
    self.value = query.defaultValue
  }
}

// MARK: - ToOptionalQuery

private struct ToOptionalQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base

  func fetch(in context: QueryContext) async throws -> Base.Value? {
    try await self.base.fetch(in: context)
  }
}
