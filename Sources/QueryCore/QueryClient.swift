import IssueReporting

// MARK: - QueryClient

public final class QueryClient: Sendable {
  private let stores = Lock<[QueryPath: StoreEntry]>([:])

  public init() {}
}

// MARK: - Store

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStore<Query.Value?> {
    QueryStore(query: query, state: self.queryStateStore(for: query, initialValue: nil))
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<Query.Value> {
    QueryStore(
      query: query,
      state: self.queryStateStore(for: query, initialValue: query.defaultValue)
    )
  }

  private func queryStateStore<Query: QueryProtocol>(
    for query: Query,
    initialValue: Query.Value?
  ) -> QueryStateStore<Query.Value?> {
    self.stores.withLock { stores in
      if let entry = stores[query.path],
        let store = entry.stateStore as? QueryStateStore<Query.Value?>
      {
        if entry.queryType != Query.self {
          duplicatePathWarning(expectedType: entry.queryType, foundType: Query.self)
        }
        return store
      }
      let store = QueryStateStore<Query.Value?>(initialValue: initialValue)
      stores[query.path] = StoreEntry(queryType: Query.self, stateStore: store)
      return store
    }
  }
}

// MARK: - Store Entry

extension QueryClient {
  private struct StoreEntry {
    let queryType: Any.Type
    let stateStore: Any
  }
}

// MARK: - Warning

private func duplicatePathWarning(expectedType: Any.Type, foundType: Any.Type) {
  reportIssue(
    """
    A QueryClient has detected a duplicate QueryPath used for different QueryProtocol conformances.

        Expected: \(String(reflecting: expectedType))
           Found: \(String(reflecting: foundType))

    The returned QueryStore instance will use the expected QueryProtocol conformance type for \
    data fetching.

    To fix this, ensure that all of your QueryProtocol conformances return unique QueryPath \
    instances. If your QueryProtocol conformance type conforms to Hashable, the default QueryPath \
    is represented by a single element path containing the instance of the type itself.
    """
  )
}
