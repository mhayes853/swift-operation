// MARK: - QueryStore

public final class QueryStore<Value: Sendable>: Sendable {
  private let query: any QueryProtocol<Value>
  private let state: Lock<Value>

  public let defaultValue: Value

  init<V>(query: some QueryProtocol<V>) where Value == V? {
    self.query = ToOptionalQuery(base: query)
    self.state = Lock(nil)
    self.defaultValue = nil
  }

  init(query: DefaultQuery<some QueryProtocol<Value>>) {
    self.query = query
    self.state = Lock(query.defaultValue)
    self.defaultValue = query.defaultValue
  }
}

// MARK: - Current Value

extension QueryStore {
  public var value: Value {
    self.state.withLock { $0 }
  }
}

// MARK: - Fetching

extension QueryStore {
  public func fetch() async throws -> Value {
    let value = try await self.query.fetch(in: QueryContext())
    self.state.withLock { $0 = value }
    return value
  }
}

// MARK: - ToOptionalQuery

private struct ToOptionalQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base

  func fetch(in context: QueryContext) async throws -> Base.Value? {
    try await self.base.fetch(in: context)
  }
}
