import IssueReporting
import OrderedCollections

// MARK: - QueryClient

public final class QueryClient: Sendable {
  private let stores = Lock<[QueryPath: StoreEntry]>([:])

  public init() {}
}

// MARK: - Store

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStore<Query.Value?> {
    QueryStore(Query.Value?.self, base: self.anyStore(for: query, initialValue: nil))
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<Query.Value> {
    QueryStore(Query.Value.self, base: self.anyStore(for: query, initialValue: query.defaultValue))
  }

  private func anyStore<Query: QueryProtocol>(
    for query: Query,
    initialValue: Query.Value?
  ) -> AnyQueryStore {
    self.stores.withLock { stores in
      if let entry = stores[query.path] {
        if entry.queryType != Query.self {
          duplicatePathWarning(expectedType: entry.queryType, foundType: Query.self)
          return AnyQueryStore(query: query, initialValue: initialValue)
        }
        return entry.store
      }
      let store = AnyQueryStore(query: query, initialValue: initialValue)
      stores[query.path] = StoreEntry(queryType: Query.self, store: store)
      return store
    }
  }
}

// MARK: - Queries For Path

extension QueryClient {
  public func queries(matching path: QueryPath) -> [QueryPath: AnyQueryStore] {
    self.stores.withLock {
      var newValues = [QueryPath: AnyQueryStore]()
      for (queryPath, entry) in $0 {
        if path.prefixMatches(other: queryPath) {
          newValues[queryPath] = entry.store
        }
      }
      return newValues
    }
  }
}

// MARK: - Store Entry

extension QueryClient {
  private struct StoreEntry {
    let queryType: Any.Type
    let store: AnyQueryStore
  }
}

// MARK: - Warning

private func duplicatePathWarning(expectedType: Any.Type, foundType: Any.Type) {
  reportIssue(
    """
    A QueryClient has detected a duplicate QueryPath used for different QueryProtocol conformances.

        Expected: \(String(reflecting: expectedType))
           Found: \(String(reflecting: foundType))

    A new QueryStore instance will be created for the type with the duplicate key, and this store \
    will not be retained within the QueryClient. This means that the state will not be shared \
    between different QueryStore instances, and you will not be able to pattern match the query \
    when calling ``QueryClient.queries(path:)``.

    To fix this, ensure that all of your QueryProtocol conformances return unique QueryPath \
    instances. If your QueryProtocol conformance type conforms to Hashable, the default QueryPath \
    is represented by a single element path containing the instance of the query itself.
    """
  )
}
