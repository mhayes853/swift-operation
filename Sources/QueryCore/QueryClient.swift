// MARK: - QueryClient

public final class QueryClient: Sendable {
  private let stores = Lock<[AnyHashable: Any]>([:])

  public init() {}
}

// MARK: - Store

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStore<Query.Value?> {
    self.stores.withLock { stores in
      let key = AnyHashable(query.id)
      if let store = stores[key] as? QueryStateStore<Query.Value?> {
        return QueryStore(query: query, state: store)
      }
      let store = QueryStateStore<Query.Value?>(initialValue: nil)
      stores[key] = store
      return QueryStore(query: query, state: store)
    }
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<Query.Value> {
    self.stores.withLock { stores in
      let key = AnyHashable(query.id)
      if let store = stores[key] as? QueryStateStore<Query.Value?> {
        return QueryStore(query: query, state: store)
      }
      let store = QueryStateStore<Query.Value?>(initialValue: query.defaultValue)
      stores[key] = store
      return QueryStore(query: query, state: store)
    }
  }
}
