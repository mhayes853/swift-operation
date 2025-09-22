import IdentifiedCollections
import IssueReporting

// MARK: - OperationClient

/// A class that manages all ``OperationStore`` instances in your application.
///
/// Generally, you should only create a single `OperationClient` instance, and share it across your entire
/// application. The singleton instance will provide access to all `OperationStore` instances in your
/// application. Adapters such as the `@SharedOperation` property wrapper uses this class under
/// the hood to acces the underlying stores they observe.
///
/// If you want to create an `OperationStore` that exists outside of a query client, you can use
/// when of the `detached` static initializers on `OperationStore`. Stores created through the
/// `detached` static initializers will not be associated with an `OperationClient`, and will
/// manage their operation's state in isolation.
///
/// You will most commonly interact with an `OperationClient` when you need to perform global state
/// management operations across multiple different operation. You can find more about how to do
/// this in <doc:PatternMatchingAndStateManagement>.
///
/// ```swift
/// struct SendFriendRequestMutation: MutationRequest, Hashable {
///   // ...
///
///   func mutate(
///     isolation: isolated (any Actor)?,
///     with arguments: Arguments,
///     in context: OperationContext,
///     with continuation: OperationContinuation<Void, any Error>
///   ) async throws {
///     try await sendFriendRequest(userId: arguments.userId)
///
///     // Friend request sent successfully, now update all
///     // friends lists in the app.
///     guard let client = context.operationClient else { return }
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
/// `OperationClient` manages the in-memory storage for its stores via the ``StoreCache`` protocol.
/// The default implementation of this protocol will evict stores from memory when the system runs
/// low on memory. You can also write your own conformance to this protocol if you wish to
/// customize how the client's stores are managed in memory such as via an LRU or garbage
/// collection scheme.
///
/// You can also customize the client's creation of `OperationStore` instances through the
/// ``StoreCreator`` protocol. The default implementation applies some default modifiers to each
/// operation when a store is created. If you want to override those default modifiers, consider
/// creating a conformance to the protocol, and passing the conformance to
/// ``init(defaultContext:storeCache:storeCreator:)``. For more on this, read
/// <doc:OperationDefaults>.
public final class OperationClient: Sendable {
  private struct State {
    let storeCreator: any OperationClient.StoreCreator
    var storeCache: any StoreCache
    var initialContext: OperationContext
    var operationTypes = [OperationPath: Any.Type]()

    func createStore() -> CreateStore {
      CreateStore(
        creator: self.storeCreator,
        initialContext: self.initialContext,
        operationTypes: MutableBox(value: self.operationTypes)
      )
    }
  }

  private let state: RecursiveLock<State>

  /// Creates a client.
  ///
  /// - Parameters:
  ///   - defaultContext: The default ``OperationContext`` to use for each ``OperationStore``
  ///   created by the client.
  ///   - storeCache: The ``StoreCache`` to use.
  ///   - storeCreator: The ``StoreCreator`` to use.
  public init(
    defaultContext: OperationContext = OperationContext(),
    storeCache: sending some StoreCache = DefaultStoreCache(),
    storeCreator: sending some StoreCreator
  ) {
    self.state = RecursiveLock(
      State(storeCreator: storeCreator, storeCache: storeCache, initialContext: defaultContext)
    )
    self.state.withLock { $0.initialContext.setWeakOperationClient(self) }
  }
}

// MARK: - Default Context

extension OperationClient {
  /// The default ``OperationContext`` that is used to create subsequent ``OperationStore``
  /// instances.
  public var defaultContext: OperationContext {
    get { self.state.withLock { $0.initialContext } }
    set { self.state.withLock { $0.initialContext = newValue } }
  }
}

// MARK: - Store

extension OperationClient {
  /// Retrieves the ``OperationStore`` for a ``StatefulOperationRequest``.
  ///
  /// - Parameters:
  ///   - operation: The operation.
  ///   - initialState: The initial state of the operation.
  /// - Returns: A ``OperationStore``.
  public func store<Operation: StatefulOperationRequest>(
    for operation: sending Operation,
    initialState: Operation.State
  ) -> OperationStore<Operation.State> {
    self.withStoreCreation(for: operation) { $0(for: $1, initialState: initialState) }
  }

  /// Retrieves the ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialState: The initial state of the query.
  /// - Returns: A ``OperationStore``.
  public func store<Query: QueryRequest>(
    for query: sending Query,
    initialState: Query.State
  ) -> OperationStore<Query.State> {
    self.withStoreCreation(for: query) { $0(for: $1, initialState: initialState) }
  }

  /// Retrieves the ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value of the query.
  /// - Returns: A ``OperationStore``.
  public func store<Query: QueryRequest>(
    for query: sending Query,
    initialValue: Query.Value? = nil
  ) -> OperationStore<Query.State> where Query.State == QueryState<Query.Value, Query.Failure> {
    self.withStoreCreation(for: query) { $0(for: $1, initialValue: initialValue) }
  }

  /// Retrieves the ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``OperationStore``.
  public func store<Query: QueryRequest>(
    for query: sending Query.Default
  ) -> OperationStore<Query.Default.State> {
    self.withStoreCreation(for: query) { $0(for: $1) }
  }

  /// Retrieves the ``OperationStore`` for a ``PaginatedRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value for the state of the query.
  /// - Returns: A ``OperationStore``.
  public func store<Query: PaginatedRequest>(
    for query: sending Query,
    initialValue: Query.State.StateValue = []
  ) -> OperationStore<Query.State> {
    self.withStoreCreation(for: query) { $0(for: $1, initialValue: initialValue) }
  }

  /// Retrieves the ``OperationStore`` for a ``PaginatedRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``OperationStore``.
  public func store<Query: PaginatedRequest>(
    for query: sending Query.Default
  ) -> OperationStore<Query.Default.State> {
    self.withStoreCreation(for: query) { $0(for: $1) }
  }

  /// Retrieves the ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - mutation: The mutation.
  ///   - initialValue: The initial value for the state of the mutation.
  /// - Returns: A ``OperationStore``.
  public func store<Mutation: MutationRequest>(
    for mutation: sending Mutation,
    initialValue: Mutation.MutateValue? = nil
  ) -> OperationStore<Mutation.State> {
    self.withStoreCreation(for: mutation) { $0(for: $1, initialValue: initialValue) }
  }

  /// Retrieves the ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - mutation: The mutation.
  /// - Returns: A ``OperationStore``.
  public func store<Mutation: MutationRequest>(
    for mutation: sending Mutation.Default
  ) -> OperationStore<Mutation.Default.State> {
    self.withStoreCreation(for: mutation) { $0(for: $1) }
  }

  private func withStoreCreation<Operation: StatefulOperationRequest>(
    for operation: sending Operation,
    _ create:
      @Sendable (
        borrowing CreateStore,
        sending Operation
      ) -> OperationStore<Operation.State>
  ) -> OperationStore<Operation.State> {
    let transfer = UnsafeTransfer(value: operation)
    return self.state.withLock { state in
      let createStore = state.createStore()
      defer { state.operationTypes = createStore.operationTypes.value }
      let type = state.operationTypes[transfer.value.path]
      return state.storeCache.withStores { stores in
        if let opaqueStore = stores[transfer.value.path] {
          if let type, type != Operation.self {
            reportWarning(.duplicatePath(expectedType: type, foundType: Operation.self))
            return create(createStore, transfer.value)
          }
          return opaqueStore.base as! OperationStore<Operation.State>
        }
        let store = create(createStore, transfer.value)
        stores.update(OpaqueOperationStore(erasing: store))
        return store
      }
    }
  }
}

// MARK: - Queries For Path

extension OperationClient {
  /// Returns a fully-type erased store with the specified ``OperationPath``.
  ///
  /// The path must be an exact match, and not a prefix match.
  ///
  /// - Parameter path: The path of the store.
  /// - Returns: An ``OpaqueOperationStore``.
  public func store(with path: OperationPath) -> OpaqueOperationStore? {
    self.state.withLock { $0.storeCache.stores()[path] }
  }

  /// Returns a collection of fully-type erased stores matching the specified ``OperationPath``.
  ///
  /// The matching is performed via ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path of the stores.
  /// - Returns: A collection of ``OpaqueOperationStore`` instances.
  public func stores(
    matching path: OperationPath
  ) -> OperationPathableCollection<OpaqueOperationStore> {
    self.state.withLock { $0.storeCache.stores().collection(matching: path) }
  }

  /// Returns a collection of ``OperationStore`` instances matching the specified ``OperationPath``.
  ///
  /// The matching is performed via ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - stateType: The data type of state that the store manages.
  /// - Returns: A collection of ``OperationStore`` instances.
  public func stores<State: OperationState>(
    matching path: OperationPath,
    of stateType: State.Type
  ) -> OperationPathableCollection<OperationStore<State>> {
    self.state.withLock { state in
      OperationPathableCollection<OperationStore<State>>(
        state.storeCache.stores()
          .collection(matching: path)
          .compactMap { $0.base as? OperationStore<State> }
      )
    }
  }
}

// MARK: - Clearing Queries

extension OperationClient {
  /// Removes stores from the client that match the specified ``OperationPath``.
  ///
  /// The matching is performed via ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path of the stores.
  public func clearStores(matching path: OperationPath = OperationPath()) {
    self.state.withLock { state in
      state.storeCache.withStores { $0.removeAll(matching: path) }
    }
  }

  /// Removes the store with the specified ``OperationPath``.
  ///
  /// The path must be an exact match, and not a prefix match.
  ///
  /// - Parameter path: The path of the store.
  /// - Returns: The removed store as an ``OpaqueOperationStore``.
  @discardableResult
  public func clearStore(with path: OperationPath) -> OpaqueOperationStore? {
    self.state.withLock { state in
      state.storeCache.withStores { $0.removeValue(forPath: path) }
    }
  }
}

// MARK: - Direct Store Access

extension OperationClient {
  /// Provides a scope to edit a collection of fully-type erased stores that match the specified
  /// ``OperationPath``.
  ///
  /// The matching is performed via ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - fn: A closure to edit the collection of stores.
  /// - Returns: Whatever `fn` returns.
  public func withStores<T>(
    matching path: OperationPath,
    perform fn:
      @Sendable (
        inout OperationPathableCollection<OpaqueOperationStore>,
        borrowing CreateStore
      ) throws -> sending T
  ) rethrows -> T {
    try self.state.withLock { state in
      let createStore = state.createStore()
      defer { state.operationTypes = createStore.operationTypes.value }
      return try state.storeCache.withStores { stores in
        let beforeEntries = stores.collection(matching: path)
        var afterEntries = beforeEntries
        let value = try fn(&afterEntries, createStore)
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
        return value
      }
    }
  }

  /// Provides a scope to edit a collection of ``OperationStore`` instances that match the specified
  /// ``OperationPath``.
  ///
  /// The matching is performed via ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - stateType: The data type of state that the store manages.
  ///   - fn: A closure to edit the collection of stores.
  /// - Returns: Whatever `fn` returns.
  public func withStores<T, State: OperationState>(
    matching path: OperationPath,
    of stateType: State.Type,
    perform fn:
      @Sendable (
        inout OperationPathableCollection<OperationStore<State>>,
        borrowing CreateStore
      ) throws -> sending T
  ) rethrows -> T {
    try self.state.withLock { state in
      let createStore = state.createStore()
      defer { state.operationTypes = createStore.operationTypes.value }
      return try state.storeCache.withStores { stores in
        let beforeEntries = OperationPathableCollection<OperationStore<State>>(
          stores.collection(matching: path).compactMap { $0.base as? OperationStore<State> }
        )
        var afterEntries = beforeEntries
        let value = try fn(&afterEntries, createStore)
        for store in afterEntries {
          if beforeEntries[store.path] == nil {
            stores.update(OpaqueOperationStore(erasing: store))
          }
        }
        for store in beforeEntries {
          if afterEntries[store.path] == nil {
            stores.removeValue(forPath: store.path)
          }
        }
        return value
      }
    }
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationClient`` in this context.
  ///
  /// By default, the client is nil. When initializing a ``OperationClient``, this property will be
  /// set to the initialized client, and will become nil when the client is deinitialized.
  ///
  /// ``OperationStore`` instances retrieved through a `OperationClient` will have this property set to
  /// the client through ``OperationStore/context``. However, if the store was created through a
  /// `detached` static initializer, then its context will not contain an associated client, and
  /// this property will be nil.
  public var operationClient: OperationClient? {
    get { self[OperationClientKey.self]?.client }
    set { self[OperationClientKey.self] = newValue.map { .strong($0) } }
  }

  fileprivate mutating func setWeakOperationClient(_ client: OperationClient) {
    self[OperationClientKey.self] = .weak(LockedWeakBox(value: client))
  }

  fileprivate enum OperationClientValue: Sendable {
    case strong(OperationClient)
    case weak(LockedWeakBox<OperationClient>)

    var client: OperationClient? {
      switch self {
      case .strong(let client): client
      case .weak(let box): box.inner.withLock { $0.value }
      }
    }
  }

  private enum OperationClientKey: Key {
    static var defaultValue: OperationClientValue? {
      nil
    }
  }
}

// MARK: - Warnings

extension OperationWarning {
  public static func duplicatePath(expectedType: Any.Type, foundType: Any.Type) -> Self {
    """
    A OperationClient has detected a duplicate OperationPath used for different OperationRequest \
    conformances.

        Expected: \(String(reflecting: expectedType))
           Found: \(String(reflecting: foundType))

    This is generally considered an application programming error. By using a different operation type \
    with the same path you open up your application to unexpected behavior around how the \ 
    OperationStore runs its operationsince a different set of modifiers can be applied to both \
    operations.

    A new OperationStore instance will be created for the type with the duplicate key, and this store \
    will not be retained within the OperationClient. This means that the state will not be shared \
    between different OperationStore instances, and you will not be able to pattern match against \
    the store when calling ``OperationClient.stores(matching:)``.

    To fix this, ensure that all of your OperationRequest conformances return unique OperationPath \
    instances. If your OperationRequest conformance type conforms to Hashable or Identifiable, the \
    default OperationPath is represented by a single element path containing the instance of its \
    hashability or identity respectively.
    """
  }
}
