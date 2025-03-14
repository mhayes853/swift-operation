import ConcurrencyExtras
import IdentifiedCollections
import IssueReporting

// MARK: - QueryClient

public final class QueryClient: Sendable {
  private typealias State = (stores: [QueryPath: StoreEntry], defaultContext: QueryContext)

  private let state: Lock<State>

  public init(defaultContext: QueryContext = QueryContext()) {
    self.state = Lock(([:], defaultContext))
    self.state.withLock { $0.defaultContext.setWeakQueryClient(self) }
  }
}

// MARK: - Default Context

extension QueryClient {
  public var defaultContext: QueryContext {
    get { self.state.withLock { $0.defaultContext } }
    set { self.state.withLock { $0.defaultContext = newValue } }
  }
}

// MARK: - Store

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStoreFor<Query>
  where Query.State == QueryState<Query.Value?, Query.Value> {
    QueryStore(
      casting: self.opaqueStore(for: query, initialState: Query.State(initialValue: nil))
    )!
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> QueryStoreFor<DefaultQuery<Query>>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    QueryStore(
      casting: self.opaqueStore(
        for: query,
        initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue)
      )
    )!
  }

  public func store<Query: InfiniteQueryProtocol>(
    for query: Query
  ) -> InfiniteQueryStoreFor<Query> {
    InfiniteQueryStore(
      casting: self.opaqueStore(
        for: query,
        initialState: InfiniteQueryState(initialValue: [], initialPageId: query.initialPageId)
      )
    )!
  }

  public func store<Query: InfiniteQueryProtocol>(
    for query: DefaultInfiniteQuery<Query>
  ) -> InfiniteQueryStoreFor<DefaultInfiniteQuery<Query>> {
    InfiniteQueryStore(
      casting: self.opaqueStore(
        for: query,
        initialState: InfiniteQueryState(
          initialValue: query.defaultValue,
          initialPageId: query.initialPageId
        )
      )
    )!
  }

  public func store<Mutation: MutationProtocol>(
    for mutation: Mutation
  ) -> MutationStoreFor<Mutation> {
    MutationStore(casting: self.opaqueStore(for: mutation, initialState: MutationState()))!
  }

  private func opaqueStore<Query: QueryProtocol>(
    for query: Query,
    initialState: Query.State
  ) -> OpaqueQueryStore where Query.State.QueryValue == Query.Value {
    self.state.withLock { state in
      let newStore = OpaqueQueryStore(
        erasing: .detached(
          query: query,
          initialState: initialState,
          initialContext: self.defaultContext
        )
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
  public func store(with path: QueryPath) -> OpaqueQueryStore? {
    self.state.withLock { $0.stores[path]?.store }
  }

  public func stores(matching path: QueryPath) -> [QueryPath: OpaqueQueryStore] {
    self.state.withLock { state in
      var newValues = [QueryPath: OpaqueQueryStore]()
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
    let store: OpaqueQueryStore
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var queryClient: QueryClient? {
    get { self[QueryClientKey.self]?.client }
    set { self[QueryClientKey.self] = newValue.map { .strong($0) } }
  }

  fileprivate mutating func setWeakQueryClient(_ client: QueryClient) {
    self[QueryClientKey.self] = .weak(LockedWeakBox(value: client))
  }

  fileprivate enum QueryClientValue: Sendable {
    case strong(QueryClient)
    case weak(LockedWeakBox<QueryClient>)

    var client: QueryClient? {
      switch self {
      case let .strong(client): client
      case let .weak(box): box.inner.withLock { $0.value }
      }
    }
  }

  private enum QueryClientKey: Key {
    static var defaultValue: QueryClientValue? {
      nil
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
}
