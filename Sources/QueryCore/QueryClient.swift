import ConcurrencyExtras
import IssueReporting

// MARK: - QueryClient

public final class QueryClient: Sendable {
  private typealias State = (stores: [QueryPath: StoreEntry], defaultContext: QueryContext)

  private let state: Lock<State>

  public init(defaultContext: QueryContext = QueryContext()) {
    self.state = Lock(([:], defaultContext))
    self.state.withLock { $0.defaultContext.queryClient = self }
  }
}

// MARK: - Default Context

extension QueryClient {
  public func withDefaultContext<T: Sendable>(
    _ fn: @Sendable (inout QueryContext) throws -> T
  ) rethrows -> T {
    try self.state.withLock { try fn(&$0.defaultContext) }
  }
}

// MARK: - Store

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStoreOf<Query> {
    QueryStore(Query.Value?.self, base: self.anyStore(for: query, initialValue: nil))
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> DefaultQueryStoreOf<Query> {
    QueryStore(Query.Value.self, base: self.anyStore(for: query, initialValue: query.defaultValue))
  }

  private func anyStore<Query: QueryProtocol>(
    for query: Query,
    initialValue: Query.Value?
  ) -> AnyQueryStore {
    self.state.withLock { state in
      let newStore = AnyQueryStore(
        query: query,
        initialValue: initialValue,
        initialContext: state.defaultContext
      )
      if let entry = state.stores[query.path] {
        if entry.queryType != Query.self {
          reportWarning(.duplicatePath(expectedType: entry.queryType, foundType: Query.self))
          return newStore
        }
        return entry.store
      }
      state.stores[query.path] = StoreEntry(queryType: Query.self, store: newStore)
      return newStore
    }
  }
}

// MARK: - Queries For Path

extension QueryClient {
  public func queries(matching path: QueryPath) -> [QueryPath: AnyQueryStore] {
    self.state.withLock { state in
      var newValues = [QueryPath: AnyQueryStore]()
      for (queryPath, entry) in state.stores {
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

// MARK: - QueryContext

extension QueryContext {
  public fileprivate(set) var queryClient: QueryClient {
    get {
      self[QueryClientKey.self].inner
        .withLock { box in
          guard let client = box.value else {
            reportWarning(.missingQueryClient)
            return QueryClient()
          }
          return client
        }
    }
    set {
      self[QueryClientKey.self].inner.withLock { $0.value = newValue }
    }
  }

  private enum QueryClientKey: Key {
    static var defaultValue: LockedWeakBox<QueryClient> {
      LockedWeakBox<QueryClient>(value: nil)
    }
  }
}

// MARK: - Warnings

extension QueryCoreWarning {
  public static func duplicatePath(expectedType: Any.Type, foundType: Any.Type) -> Self {
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
  }

  public static var missingQueryClient: Self {
    """
    No QueryClient was found in the QueryContext.

    Ensure that the QueryContext originates from a QueryClient instance. You can obtain a context \
    that originates from a QueryClient instance by calling ``QueryClient.withDefaultContext``.
    """
  }
}
