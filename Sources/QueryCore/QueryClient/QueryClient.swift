import IdentifiedCollections
import IssueReporting

// MARK: - QueryClient

public final class QueryClient: Sendable {
  private typealias State = (queryTypes: [QueryPath: Any.Type], defaultContext: QueryContext)

  private let state: Lock<State>
  private let storeCache: any StoreCache
  private let storeCreator: any StoreCreator

  public init(
    defaultContext: QueryContext = QueryContext(),
    storeCache: some StoreCache = DefaultStoreCache(),
    storeCreator: some StoreCreator
  ) {
    self.state = Lock(([:], defaultContext))
    self.storeCreator = storeCreator
    self.storeCache = storeCache
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
  public func store<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> QueryStore<Query.State> {
    self.opaqueStore(for: query, initialState: initialState).base
      as! QueryStore<Query.State>
  }

  public func store<Query: QueryRequest>(for query: Query) -> QueryStore<Query.State>
  where Query.State == QueryState<Query.Value?, Query.Value> {
    self.opaqueStore(for: query, initialState: Query.State(initialValue: nil)).base
      as! QueryStore<Query.State>
  }

  public func store<Query: QueryRequest>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<DefaultQuery<Query>.State>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    self.opaqueStore(
      for: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue)
    )
    .base as! QueryStore<DefaultQuery<Query>.State>
  }

  public func store<Query: InfiniteQueryRequest>(
    for query: Query
  ) -> QueryStore<Query.State> {
    self.opaqueStore(
      for: query,
      initialState: InfiniteQueryState(initialValue: [], initialPageId: query.initialPageId)
    )
    .base as! QueryStore<Query.State>
  }

  public func store<Query: InfiniteQueryRequest>(
    for query: DefaultInfiniteQuery<Query>
  ) -> QueryStore<DefaultInfiniteQuery<Query>.State> {
    self.opaqueStore(
      for: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      )
    )
    .base as! QueryStore<DefaultInfiniteQuery<Query>.State>
  }

  public func store<Mutation: MutationRequest>(
    for mutation: Mutation
  ) -> QueryStore<Mutation.State> {
    self.opaqueStore(for: mutation, initialState: MutationState()).base
      as! QueryStore<Mutation.State>
  }

  private func opaqueStore<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> OpaqueQueryStore {
    self.storeCache.withLock { stores in
      self.state.withLock { state in
        defer { state.queryTypes[query.path] = Query.self }
        if let store = stores[query.path] {
          if let queryType = state.queryTypes[query.path], queryType != Query.self {
            reportWarning(.duplicatePath(expectedType: queryType, foundType: Query.self))
            return self.newOpaqueStore(
              for: query,
              initialState: initialState,
              using: state.defaultContext
            )
          }
          return store
        }
        let newStore = self.newOpaqueStore(
          for: query,
          initialState: initialState,
          using: state.defaultContext
        )
        stores.update(newStore)
        return newStore
      }
    }
  }

  private func newOpaqueStore<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State,
    using context: QueryContext
  ) -> OpaqueQueryStore {
    OpaqueQueryStore(
      erasing: self.storeCreator.store(for: query, in: context, with: initialState)
    )
  }
}

// MARK: - Queries For Path

extension QueryClient {
  public func store(with path: QueryPath) -> OpaqueQueryStore? {
    self.storeCache.withLock { $0[path] }
  }

  public func stores(matching path: QueryPath) -> QueryPathableCollection<OpaqueQueryStore> {
    self.storeCache.withLock { $0.collection(matching: path) }
  }

  public func stores<State: QueryStateProtocol>(
    matching path: QueryPath,
    of stateType: State.Type
  ) -> QueryPathableCollection<QueryStore<State>> {
    self.storeCache.withLock { stores in
      QueryPathableCollection<QueryStore<State>>(
        stores.collection(matching: path).compactMap { $0.base as? QueryStore<State> }
      )
    }
  }
}

// MARK: - Clearing Queries

extension QueryClient {
  public func clearStores(matching path: QueryPath = []) {
    self.storeCache.withLock { $0.removeAll(matching: path) }
  }

  @discardableResult
  public func clearStore(with path: QueryPath) -> OpaqueQueryStore? {
    self.storeCache.withLock { $0.removeValue(forPath: path) }
  }
}

// MARK: - Direct Store Access

extension QueryClient {
  public func withStores<T>(
    matching path: QueryPath,
    perform fn: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
  ) rethrows -> T {
    try self.storeCache.withLock { entries in
      let beforeEntries = entries.collection(matching: path)
      var afterEntries = beforeEntries
      defer {
        for store in afterEntries {
          if beforeEntries[store.path] == nil {
            entries.update(store)
          }
        }
        for store in beforeEntries {
          if afterEntries[store.path] == nil {
            entries.removeValue(forPath: store.path)
          }
        }
      }
      return try fn(&afterEntries)
    }
  }

  public func withStores<T, State: QueryStateProtocol>(
    matching path: QueryPath,
    of stateType: State.Type,
    perform fn: (inout sending QueryPathableCollection<QueryStore<State>>) throws -> sending T
  ) rethrows -> T {
    try self.storeCache.withLock { entries in
      let beforeEntries = QueryPathableCollection<QueryStore<State>>(
        entries.collection(matching: path).compactMap { $0.base as? QueryStore<State> }
      )
      var afterEntries = beforeEntries
      defer {
        for store in afterEntries {
          if beforeEntries[store.path] == nil {
            entries.update(OpaqueQueryStore(erasing: store))
          }
        }
        for store in beforeEntries {
          if afterEntries[store.path] == nil {
            entries.removeValue(forPath: store.path)
          }
        }
      }
      return try fn(&afterEntries)
    }
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
      case .strong(let client): client
      case .weak(let box): box.inner.withLock { $0.value }
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

extension QueryWarning {
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
