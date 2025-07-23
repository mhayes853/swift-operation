import IdentifiedCollections
import IssueReporting

// MARK: - QueryClient

/// A class that manages all ``QueryStore`` instances in your application.
///
/// Generally, you should only create a single `QueryClient` instance, and share it across your entire
/// application. The singleton instance will provide access to all `QueryStore` instances in your
/// application. Adapters such as the `@State.Query` and `@SharedQuery` property wrappers use
/// this class under the hood to acces the underlying stores they observe.
///
/// If you want to create a `QueryStore` that exists outside of a query client, you can call
/// ``QueryStore/detached(query:initialContext:)-17q5k``. Stores created through the `detached`
/// methods will not be associated with a `QueryClient`, and will manage their query's state in isolation.
///
/// You will most commonly interact with a `QueryClient` when you need to perform global state
/// management operations across multiple different queries. You can find more about how to do
/// this in <doc:PatternMatchingAndStateManagement>.
///
/// ```swift
/// struct SendFriendRequestMutation: MutationRequest, Hashable {
///   // ...
///
///   func mutate(
///     with arguments: Arguments,
///     in context: QueryContext,
///     with continuation: QueryContinuation<Void>
///   ) async throws {
///     try await sendFriendRequest(userId: arguments.userId)
///
///     // Friend request sent successfully, now update all
///     // friends lists in the app.
///     guard let client = context.queryClient else { return }
///     let stores = client.stores(
///       matching: ["user-friends"],
///       of: User.FriendsQuery.State.self
///     )
///     for store in stores {
///       store.withExclusiveAccess {
///         store.currentValue = store.currentValue.updateRelationship(
///           for: arguments.userId,
///           to: .friendRequestSent
///         )
///       }
///     }
///   }
/// }
/// ```
///
/// `QueryClient` manages the in-memory storage for its stores via the ``StoreCache`` protocol. The
/// default implementation of this protocol will evict stores from memory when the system runs low
/// on memory. You can also write your own conformance to this protocol if you wish to customize
/// how the client's stores are managed in memory.
///
/// You can also customize the client's creation of `QueryStore` instances through the
/// ``StoreCreator`` protocol. The default implementation applies some default modifiers to each
/// query when a store is created. If you want to override those default modifiers, consider
/// creating a conformance to the protocol, and passing the conformance to
/// ``init(defaultContext:storeCache:storeCreator:)``. For more on this, read <doc:QueryDefaults>.
public final class QueryClient: Sendable {
  private struct State {
    var queryTypes = [QueryPath: Any.Type]()
    var defaultContext: QueryContext
    var storeCache: any StoreCache
    let storeCreator: any StoreCreator

    func newOpaqueStore<Query: QueryRequest>(
      for query: Query,
      initialState: Query.State,
      using context: QueryContext
    ) -> OpaqueQueryStore {
      OpaqueQueryStore(
        erasing: self.storeCreator.store(for: query, in: context, with: initialState)
      )
    }
  }

  private let state: RecursiveLock<State>

  /// Creates a client.
  ///
  /// - Parameters:
  ///   - defaultContext: The default ``QueryContext`` to use for each ``QueryStore`` created by the client.
  ///   - storeCache: The ``StoreCache`` to use.
  ///   - storeCreator: The ``StoreCreator`` to use.
  public init(
    defaultContext: QueryContext = QueryContext(),
    storeCache: sending some StoreCache = DefaultStoreCache(),
    storeCreator: sending some StoreCreator
  ) {
    self.state = RecursiveLock(
      State(defaultContext: defaultContext, storeCache: storeCache, storeCreator: storeCreator)
    )
    self.state.withLock { $0.defaultContext.setWeakQueryClient(self) }
  }
}

// MARK: - Default Context

extension QueryClient {
  /// The default ``QueryContext`` that is used to create subsequent ``QueryStore`` instances.
  public var defaultContext: QueryContext {
    get { self.state.withLock { $0.defaultContext } }
    set { self.state.withLock { $0.defaultContext = newValue } }
  }
}

// MARK: - Store

extension QueryClient {
  /// Retrieves the ``QueryStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialState: The initial state of the query.
  /// - Returns: A ``QueryStore``.
  public func store<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> QueryStore<Query.State> {
    self.opaqueStore(for: query, initialState: initialState).base
      as! QueryStore<Query.State>
  }

  /// Retrieves the ``QueryStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value of the query.
  /// - Returns: A ``QueryStore``.
  public func store<Query: QueryRequest>(
    for query: Query,
    initialValue: Query.Value? = nil
  ) -> QueryStore<Query.State>
  where Query.State == QueryState<Query.Value?, Query.Value> {
    self.opaqueStore(for: query, initialState: Query.State(initialValue: initialValue)).base
      as! QueryStore<Query.State>
  }

  /// Retrieves the ``QueryStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``QueryStore``.
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

  /// Retrieves the ``QueryStore`` for an ``InfiniteQueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value for the state of the query.
  /// - Returns: A ``QueryStore``.
  public func store<Query: InfiniteQueryRequest>(
    for query: Query,
    initialValue: Query.State.StateValue = []
  ) -> QueryStore<Query.State> {
    self.opaqueStore(
      for: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      )
    )
    .base as! QueryStore<Query.State>
  }

  /// Retrieves the ``QueryStore`` for an ``InfiniteQueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``QueryStore``.
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

  /// Retrieves the ``QueryStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - query: The mutation.
  ///   - initialValue: The initial value for the state of the mutation.
  /// - Returns: A ``QueryStore``.
  public func store<Mutation: MutationRequest>(
    for mutation: Mutation,
    initialValue: Mutation.State.StateValue = nil
  ) -> QueryStore<Mutation.State> {
    self.opaqueStore(for: mutation, initialState: MutationState(initialValue: initialValue)).base
      as! QueryStore<Mutation.State>
  }

  private func opaqueStore<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> OpaqueQueryStore {
    self.state.withLock { state in
      defer { state.queryTypes[query.path] = Query.self }
      let storeCreator = state.storeCreator
      return state.storeCache.withStores { stores in
        if let store = stores[query.path] {
          if let queryType = state.queryTypes[query.path], queryType != Query.self {
            reportWarning(.duplicatePath(expectedType: queryType, foundType: Query.self))
            return OpaqueQueryStore(
              erasing: storeCreator.store(
                for: query,
                in: state.defaultContext,
                with: initialState
              )
            )
          }
          return store
        }
        let newStore = OpaqueQueryStore(
          erasing: storeCreator.store(
            for: query,
            in: state.defaultContext,
            with: initialState
          )
        )
        stores.update(newStore)
        return newStore
      }
    }
  }
}

// MARK: - Queries For Path

extension QueryClient {
  /// Returns a fully-type erased store with the specified ``QueryPath``.
  ///
  /// The path must be an exact match, and not a prefix match.
  ///
  /// - Parameter path: The path of the store.
  /// - Returns: An ``OpaqueQueryStore``.
  public func store(with path: QueryPath) -> OpaqueQueryStore? {
    self.state.withLock { $0.storeCache.stores()[path] }
  }

  /// Returns a collection of fully-type erased stores matching the specified ``QueryPath``.
  ///
  /// The matching is performed via ``QueryPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path of the stores.
  /// - Returns: A collection of ``OpaqueQueryStore`` instances.
  public func stores(matching path: QueryPath) -> QueryPathableCollection<OpaqueQueryStore> {
    self.state.withLock { $0.storeCache.stores().collection(matching: path) }
  }

  /// Returns a collection of ``QueryStore`` instances matching the specified ``QueryPath``.
  ///
  /// The matching is performed via ``QueryPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - stateType: The data type of state that the store manages.
  /// - Returns: A collection of ``QueryStore`` instances.
  public func stores<State: QueryStateProtocol>(
    matching path: QueryPath,
    of stateType: State.Type
  ) -> QueryPathableCollection<QueryStore<State>> {
    self.state.withLock { state in
      QueryPathableCollection<QueryStore<State>>(
        state.storeCache.stores()
          .collection(matching: path)
          .compactMap { $0.base as? QueryStore<State> }
      )
    }
  }
}

// MARK: - Clearing Queries

extension QueryClient {
  /// Removes stores from the client that match the specified ``QueryPath``.
  ///
  /// The matching is performed via ``QueryPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path of the stores.
  public func clearStores(matching path: QueryPath = QueryPath()) {
    self.state.withLock { state in
      state.storeCache.withStores { $0.removeAll(matching: path) }
    }
  }

  /// Removes the store with the specified ``QueryPath``.
  ///
  /// The path must be an exact match, and not a prefix match.
  ///
  /// - Parameter path: The path of the store.
  /// - Returns: The removed store as an ``OpaqueQueryStore``.
  @discardableResult
  public func clearStore(with path: QueryPath) -> OpaqueQueryStore? {
    self.state.withLock { state in
      state.storeCache.withStores { $0.removeValue(forPath: path) }
    }
  }
}

// MARK: - Direct Store Access

extension QueryClient {
  /// Provides a scope to edit a collection of fully-type erased stores that match the specified
  /// ``QueryPath``.
  ///
  /// The matching is performed via ``QueryPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - fn: A closure to edit the collection of stores.
  /// - Returns: Whatever `fn` returns.
  public func withStores<T>(
    matching path: QueryPath,
    perform fn: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
  ) rethrows -> T {
    try self.state.withLock { state in
      let beforeEntries = state.storeCache.stores().collection(matching: path)
      var afterEntries = beforeEntries
      defer {
        state.storeCache.withStores { stores in
          for store in afterEntries {
            if beforeEntries[store.path] == nil {
              stores.update(store)
            }
          }
          for store in beforeEntries {
            if afterEntries[store.path] == nil {
              stores.removeValue(forPath: store.path)
            }
          }
        }
      }
      return try fn(&afterEntries)
    }
  }

  /// Provides a scope to edit a collection of ``QueryStore`` instances that match the specified
  /// ``QueryPath``.
  ///
  /// The matching is performed via ``QueryPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - stateType: The data type of state that the store manages.
  ///   - fn: A closure to edit the collection of stores.
  /// - Returns: Whatever `fn` returns.
  public func withStores<T, State: QueryStateProtocol>(
    matching path: QueryPath,
    of stateType: State.Type,
    perform fn: (inout sending QueryPathableCollection<QueryStore<State>>) throws -> sending T
  ) rethrows -> T {
    try self.state.withLock { state in
      let beforeEntries = QueryPathableCollection<QueryStore<State>>(
        state.storeCache.stores().collection(matching: path)
          .compactMap { $0.base as? QueryStore<State> }
      )
      var afterEntries = beforeEntries
      defer {
        state.storeCache.withStores { stores in
          for store in afterEntries {
            if beforeEntries[store.path] == nil {
              stores.update(OpaqueQueryStore(erasing: store))
            }
          }
          for store in beforeEntries {
            if afterEntries[store.path] == nil {
              stores.removeValue(forPath: store.path)
            }
          }
        }
      }
      return try fn(&afterEntries)
    }
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The ``QueryClient`` in this context.
  ///
  /// By default, the client is nil. When initializing a ``QueryClient``, this property will be
  /// set to the initialized client, and will become nil when the client is deinitialized.
  ///
  /// ``QueryStore`` instances retrieved through a `QueryClient` will have this property set to
  /// the client through ``QueryStore/context``. However, if the store was created through
  /// ``QueryStore/detached(query:initialContext:)``, then its context will not contain
  /// an associated client, and this property will be nil.
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

    This is generally considered an application programming error. By using a different query type \
    with the same path you open up your application to unexpected behavior around how a query \
    fetches its data since a different set of modifiers can be applied to both queries.

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
