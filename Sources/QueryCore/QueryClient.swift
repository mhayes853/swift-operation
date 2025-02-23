// MARK: - QueryClient

public final class QueryClient: Sendable {
  private let stores = Lock<[QueryPath: Any]>([:])

  public init() {}
}

// MARK: - Store

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStore<Query.Value?> {
    self.stores.withLock { stores in
      if let store = stores[query.path] as? QueryStateStore<Query.Value?> {
        return QueryStore(query: query, state: store)
      }
      let store = QueryStateStore<Query.Value?>(initialValue: nil)
      stores[query.path] = store
      return QueryStore(query: query, state: store)
    }
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<Query.Value> {
    self.stores.withLock { stores in
      if let store = stores[query.path] as? QueryStateStore<Query.Value?> {
        return QueryStore(query: query, state: store)
      }
      let store = QueryStateStore<Query.Value?>(initialValue: query.defaultValue)
      stores[query.path] = store
      return QueryStore(query: query, state: store)
    }
  }
}
