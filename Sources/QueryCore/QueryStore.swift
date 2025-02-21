// MARK: - QueryStore

public final class QueryStore<Value: Sendable>: Sendable {
  private let query: any QueryProtocol<Value>
  private let state: QueryStateStore<Value?>

  public let defaultValue: Value

  init<V>(query: some QueryProtocol<V>, state: QueryStateStore<V?>) where Value == V? {
    self.query = ToOptionalQuery(base: query)
    self.state = unsafeBitCast(state, to: QueryStateStore<Value?>.self)
    self.defaultValue = nil
  }

  init(query: DefaultQuery<some QueryProtocol<Value>>, state: QueryStateStore<Value?>) {
    self.query = query
    self.state = state
    self.defaultValue = query.defaultValue
  }
}

// MARK: - State

extension QueryStore {
  public var value: Value {
    self.state.value ?? self.defaultValue
  }

  public var isLoading: Bool {
    self.state.isLoading
  }
}

// MARK: - Fetching

extension QueryStore {
  @discardableResult
  public func fetch() async throws -> Value {
    self.state.isLoading = true
    defer { self.state.isLoading = false }
    let value = try await self.query.fetch(in: QueryContext())
    self.state.value = value
    return value
  }
}

// MARK: - ToOptionalQuery

private struct ToOptionalQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base

  var id: Base.ID {
    self.base.id
  }

  func fetch(in context: QueryContext) async throws -> Base.Value? {
    try await self.base.fetch(in: context)
  }
}
