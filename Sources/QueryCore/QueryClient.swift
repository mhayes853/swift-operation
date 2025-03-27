import ConcurrencyExtras
import IdentifiedCollections
import IssueReporting

// MARK: - QueryClient

public final class QueryClient: Sendable {
  private typealias State = (stores: [QueryPath: StoreEntry], defaultContext: QueryContext)

  private let state: Lock<State>
  private let storeCreator: any StoreCreator

  public init(
    defaultContext: QueryContext = QueryContext(),
    storeCreator: some StoreCreator = isTesting ? .defaultTesting : .default()
  ) {
    self.state = Lock(([:], defaultContext))
    self.storeCreator = storeCreator
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
  ) -> QueryStore<Query.State> where Query.Value == Query.State.QueryValue {
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
  ) -> InfiniteQueryStoreFor<Query> {
    InfiniteQueryStore(
      store:
        self.opaqueStore(
          for: query,
          initialState: InfiniteQueryState(initialValue: [], initialPageId: query.initialPageId)
        )
        .base as! QueryStore<Query.State>
    )
  }

  public func store<Query: InfiniteQueryRequest>(
    for query: DefaultInfiniteQuery<Query>
  ) -> InfiniteQueryStoreFor<DefaultInfiniteQuery<Query>> {
    InfiniteQueryStore(
      store:
        self.opaqueStore(
          for: query,
          initialState: InfiniteQueryState(
            initialValue: query.defaultValue,
            initialPageId: query.initialPageId
          )
        )
        .base as! QueryStore<Query.State>
    )
  }

  public func store<Mutation: MutationRequest>(
    for mutation: Mutation
  ) -> MutationStoreFor<Mutation> {
    MutationStore(
      store: self.opaqueStore(for: mutation, initialState: MutationState()).base
        as! QueryStore<Mutation.State>
    )
  }

  private func opaqueStore<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> OpaqueQueryStore where Query.State.QueryValue == Query.Value {
    self.state.withLock { state in
      if let entry = state.stores[query.path] {
        if entry.queryType != Query.self {
          reportWarning(.duplicatePath(expectedType: entry.queryType, foundType: Query.self))
          return self.newOpaqueStore(
            for: query,
            initialState: initialState,
            using: state.defaultContext
          )
        }
        return entry.store
      }
      let newStore = self.newOpaqueStore(
        for: query,
        initialState: initialState,
        using: state.defaultContext
      )
      state.stores[query.path] = StoreEntry(queryType: Query.self, store: newStore)
      return newStore
    }
  }

  private func newOpaqueStore<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State,
    using context: QueryContext
  ) -> OpaqueQueryStore where Query.State.QueryValue == Query.Value {
    OpaqueQueryStore(
      erasing: self.storeCreator.store(for: query, in: context, with: initialState)
    )
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

// MARK: - Clearing Queries

extension QueryClient {
  public func clearStores(matching path: QueryPath = []) {
    self.state.withLock { state in
      state.stores = state.stores.filter { !path.prefixMatches(other: $0.key) }
    }
  }

  @discardableResult
  public func clearStore(with path: QueryPath) -> OpaqueQueryStore? {
    self.state.withLock { state in
      state.stores.removeValue(forKey: path)?.store
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

// MARK: - StoreCreator

extension QueryClient {
  public protocol StoreCreator: Sendable {
    func store<Query: QueryRequest>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State> where Query.State.QueryValue == Query.Value
  }
}

extension QueryClient {
  public struct DefaultStoreCreator: StoreCreator {
    let retryLimit: Int
    let retryBackoff: QueryBackoffFunction?
    let retryDelayer: (any QueryDelayer)?
    let queryEnableAutomaticFetchingCondition: any FetchCondition
    let networkObserver: (any NetworkObserver)?
    let focusCondition: FocusCondition?

    public func store<Query: QueryRequest>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State> where Query.State.QueryValue == Query.Value {
      if query is any MutationRequest {
        return .detached(
          query: query.retry(
            limit: self.retryLimit,
            backoff: self.retryBackoff,
            delayer: self.retryDelayer
          ),
          initialState: initialState,
          initialContext: context
        )
      }
      return .detached(
        query:
          query.retry(
            limit: self.retryLimit,
            backoff: self.retryBackoff,
            delayer: self.retryDelayer
          )
          .enableAutomaticFetching(
            when: AnyFetchCondition(self.queryEnableAutomaticFetchingCondition)
          )
          .refetchOnChange(of: self.refetchOnChangeCondition)
          .deduplicated(),
        initialState: initialState,
        initialContext: context
      )
    }

    private var refetchOnChangeCondition: AnyFetchCondition {
      switch (self.networkObserver, self.focusCondition) {
      case let (observer?, focusCondition?):
        return AnyFetchCondition(.connected(to: observer) && focusCondition)
      case let (observer?, _):
        return AnyFetchCondition(.connected(to: observer))
      case let (_, focusCondition?):
        return AnyFetchCondition(focusCondition)
      default:
        return AnyFetchCondition(.always(false))
      }
    }
  }
}

extension QueryClient.StoreCreator where Self == QueryClient.DefaultStoreCreator {
  public static var defaultTesting: Self {
    .default(
      retryLimit: 0,
      retryBackoff: .noBackoff,
      retryDelayer: .noDelay,
      queryEnableAutomaticFetchingCondition: .always(true),
      networkObserver: nil,
      focusCondition: nil
    )
  }

  public static func `default`(
    retryLimit: Int = 3,
    retryBackoff: QueryBackoffFunction? = nil,
    retryDelayer: (any QueryDelayer)? = nil,
    queryEnableAutomaticFetchingCondition: any FetchCondition = .always(true),
    networkObserver: (any NetworkObserver)? = _defaultNetworkObserver,
    focusCondition: FocusCondition? = _defaultFocusCondition
  ) -> Self {
    Self(
      retryLimit: retryLimit,
      retryBackoff: retryBackoff,
      retryDelayer: retryDelayer,
      queryEnableAutomaticFetchingCondition: queryEnableAutomaticFetchingCondition,
      networkObserver: networkObserver,
      focusCondition: focusCondition
    )
  }
}

public var _defaultNetworkObserver: (any NetworkObserver)? {
  #if canImport(Network)
    NWPathMonitorObserver.shared
  #else 
    nil
  #endif
}

public var _defaultFocusCondition: FocusCondition? {
  #if canImport(Darwin)
    .shared
  #else
    nil
  #endif
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
