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
/// struct SendFriendRequestArguments: Sendable {
///   let userId: Int
/// }
///
/// @MutationRequest
/// func sendFriendRequestMutation(
///   arguments: SendFriendRequestArguments
/// ) async throws {
///   @Dependency(\.defaultOperationClient) var client
///   try await sendFriendRequest(userId: arguments.userId)
///
///   // Friend request sent successfully, now update all
///   // friends lists in the app.
///   guard let client = context.operationClient else { return }
///   let stores = client.stores(
///     matching: ["user-friends"],
///     of: PaginatedState<[User], Int>.self
///   )
///   for store in stores {
///     store.withExclusiveAccess {
///       store.currentValue = store.currentValue.updateRelationship(
///         for: arguments.userId,
///         to: .friendRequestSent
///       )
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
    struct Subscription {
      let handler: @Sendable (OpaqueSubscriptionChange) -> Void
      let matchablePath: OperationPath
    }

    var initialContext: OperationContext
    var operationTypes = [OperationPath: Any.Type]()
    var subscriptions = OperationSubscriptions<Subscription>()

    func sendSubscriptionChange(change: OpaqueSubscriptionChange) {
      self.subscriptions.forEach { subscription in
        let change = OpaqueSubscriptionChange(
          storesAdded: change.storesAdded.collection(matching: subscription.matchablePath),
          storesRemoved: change.storesRemoved.collection(matching: subscription.matchablePath)
        )
        guard !change.isEmpty else { return }
        subscription.handler(change)
      }
    }
  }

  private let storeCreator: any StoreCreator & Sendable
  private let storeCache: any StoreCache & Sendable

  private let state: RecursiveLock<State>

  /// Creates an operation client.
  ///
  /// - Parameters:
  ///   - defaultContext: The default ``OperationContext`` to use for each ``OperationStore``
  ///   created by the client.
  ///   - storeCache: The ``StoreCache`` to use.
  ///   - storeCreator: The ``StoreCreator`` to use.
  public init(
    defaultContext: OperationContext = OperationContext(),
    storeCache: some StoreCache & Sendable = DefaultStoreCache(),
    storeCreator: some StoreCreator & Sendable
  ) {
    self.storeCache = storeCache
    self.storeCreator = storeCreator
    self.state = RecursiveLock(State(initialContext: defaultContext))
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
  /// - Returns: An ``OperationStore``.
  public func store<Operation: StatefulOperationRequest>(
    for operation: sending Operation,
    initialState: Operation.State
  ) -> OperationStore<Operation.State> {
    self.withStoreCreation(for: operation) { $0(for: $1.value, initialState: initialState) }
  }

  /// Retrieves the ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialState: The initial state of the query.
  /// - Returns: An ``OperationStore``.
  public func store<Query: QueryRequest>(
    for query: sending Query,
    initialState: Query.State
  ) -> OperationStore<Query.State> {
    self.withStoreCreation(for: query) { $0(for: $1.value, initialState: initialState) }
  }

  /// Retrieves the ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value of the query.
  /// - Returns: An ``OperationStore``.
  public func store<Query: QueryRequest>(
    for query: sending Query,
    initialValue: Query.Value? = nil
  ) -> OperationStore<Query.State> where Query.State == QueryState<Query.Value, Query.Failure> {
    self.withStoreCreation(for: query) { $0(for: $1.value, initialValue: initialValue) }
  }

  /// Retrieves the ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: An ``OperationStore``.
  public func store<Query: QueryRequest>(
    for query: sending Query.Default
  ) -> OperationStore<Query.Default.State> {
    self.withStoreCreation(for: query) { $0(for: $1.value) }
  }

  /// Retrieves the ``OperationStore`` for a ``PaginatedRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value for the state of the query.
  /// - Returns: An ``OperationStore``.
  public func store<Query: PaginatedRequest>(
    for query: sending Query,
    initialValue: Query.State.StateValue = []
  ) -> OperationStore<Query.State> {
    self.withStoreCreation(for: query) { $0(for: $1.value, initialValue: initialValue) }
  }

  /// Retrieves the ``OperationStore`` for a ``PaginatedRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: An ``OperationStore``.
  public func store<Query: PaginatedRequest>(
    for query: sending Query.Default
  ) -> OperationStore<Query.Default.State> {
    self.withStoreCreation(for: query) { $0(for: $1.value) }
  }

  /// Retrieves the ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - mutation: The mutation.
  ///   - initialValue: The initial value for the state of the mutation.
  /// - Returns: An ``OperationStore``.
  public func store<Mutation: MutationRequest>(
    for mutation: sending Mutation,
    initialValue: Mutation.MutateValue? = nil
  ) -> OperationStore<Mutation.State> {
    self.withStoreCreation(for: mutation) { $0(for: $1.value, initialValue: initialValue) }
  }

  /// Retrieves the ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - mutation: The mutation.
  /// - Returns: An ``OperationStore``.
  public func store<Mutation: MutationRequest>(
    for mutation: sending Mutation.Default
  ) -> OperationStore<Mutation.Default.State> {
    self.withStoreCreation(for: mutation) { $0(for: $1.value) }
  }

  private func withStoreCreation<Operation: StatefulOperationRequest>(
    for operation: sending Operation,
    _ create: (
      borrowing CreateStore,
      sending UnsafeTransfer<Operation>
    ) -> OperationStore<Operation.State>
  ) -> OperationStore<Operation.State> {
    let transfer = UnsafeTransfer(value: operation)
    return self.state.withLock { state in
      let createStore = self.createStore(in: state)
      defer { state.operationTypes = createStore.operationTypes.value }
      let type = state.operationTypes[transfer.value.path]
      return self.storeCache.withStores { stores in
        if let opaqueStore = stores[transfer.value.path] {
          if let type, type != Operation.self {
            reportWarning(.duplicatePath(expectedType: type, foundType: Operation.self))
            return create(createStore, transfer)
          }
          return opaqueStore.base as! OperationStore<Operation.State>
        }
        let store = create(createStore, transfer)
        let opaqueStore = OpaqueOperationStore(erasing: store)
        state.sendSubscriptionChange(
          change: OpaqueSubscriptionChange(storesAdded: [opaqueStore])
        )
        stores.update(opaqueStore)
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
    self.storeCache.stores()[path]
  }

  /// Returns a collection of fully-type erased stores matching the specified ``OperationPath``.
  ///
  /// The matching is performed vian ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path of the stores.
  /// - Returns: A collection of ``OpaqueOperationStore`` instances.
  public func stores(
    matching path: OperationPath
  ) -> OperationPathableCollection<OpaqueOperationStore> {
    self.storeCache.stores().collection(matching: path)
  }

  /// Returns a collection of ``OperationStore`` instances matching the specified ``OperationPath``.
  ///
  /// The matching is performed vian ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - stateType: The data type of state that the store manages.
  /// - Returns: A collection of ``OperationStore`` instances.
  public func stores<State: OperationState>(
    matching path: OperationPath,
    of stateType: State.Type
  ) -> OperationPathableCollection<OperationStore<State>> {
    OperationPathableCollection<OperationStore<State>>(
      self.storeCache.stores()
        .collection(matching: path)
        .compactMap { $0.base as? OperationStore<State> }
    )
  }
}

// MARK: - Clearing Queries

extension OperationClient {
  /// Removes stores from the client that match the specified ``OperationPath``.
  ///
  /// The matching is performed vian ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path of the stores.
  public func clearStores(matching path: OperationPath = OperationPath()) {
    self.state.withLock { state in
      let stores = self.storeCache.withStores {
        let stores = $0.collection(matching: path)
        $0.removeAll(matching: path)
        return stores
      }
      state.sendSubscriptionChange(change: OpaqueSubscriptionChange(storesRemoved: stores))
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
      let store = self.storeCache.withStores { $0.removeValue(forPath: path) }
      state.sendSubscriptionChange(
        change: OpaqueSubscriptionChange(
          storesRemoved: store.map { [$0] } ?? OperationPathableCollection()
        )
      )
      return store
    }
  }
}

// MARK: - Direct Store Access

extension OperationClient {
  /// Provides a scope to edit a collection of fully-type erased stores that match the specified
  /// ``OperationPath``.
  ///
  /// The matching is performed vian ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - fn: A closure to edit the collection of stores.
  /// - Returns: Whatever `fn` returns.
  public func withStores<T>(
    matching path: OperationPath,
    perform fn: (
      inout OperationPathableCollection<OpaqueOperationStore>,
      borrowing CreateStore
    ) throws -> sending T
  ) rethrows -> T {
    try self.state.withLock { state in
      let createStore = self.createStore(in: state)
      defer { state.operationTypes = createStore.operationTypes.value }
      return try self.storeCache.withStores { stores in
        let beforeEntries = stores.collection(matching: path)
        var afterEntries = beforeEntries
        let value = try fn(&afterEntries, createStore)
        var change = OpaqueSubscriptionChange()
        for store in afterEntries {
          if beforeEntries[store.path] == nil {
            change.storesAdded.update(store)
            stores.update(store)
          }
        }
        for store in beforeEntries {
          if afterEntries[store.path] == nil {
            change.storesRemoved.update(store)
            stores.removeValue(forPath: store.path)
          }
        }
        state.sendSubscriptionChange(change: change)
        return value
      }
    }
  }

  /// Provides a scope to edit a collection of ``OperationStore`` instances that match the specified
  /// ``OperationPath``.
  ///
  /// The matching is performed vian ``OperationPath/isPrefix(of:)``.
  ///
  /// - Parameters:
  ///   - path: The path of the stores.
  ///   - stateType: The data type of state that the store manages.
  ///   - fn: A closure to edit the collection of stores.
  /// - Returns: Whatever `fn` returns.
  public func withStores<T, State: OperationState>(
    matching path: OperationPath,
    of stateType: State.Type,
    perform fn: (
      inout OperationPathableCollection<OperationStore<State>>,
      borrowing CreateStore
    ) throws -> sending T
  ) rethrows -> T {
    try self.state.withLock { state in
      let createStore = self.createStore(in: state)
      defer { state.operationTypes = createStore.operationTypes.value }
      return try self.storeCache.withStores { stores in
        let beforeEntries = OperationPathableCollection<OperationStore<State>>(
          stores.collection(matching: path).compactMap { $0.base as? OperationStore<State> }
        )
        var afterEntries = beforeEntries
        let value = try fn(&afterEntries, createStore)
        var change = OpaqueSubscriptionChange()
        for store in afterEntries {
          if beforeEntries[store.path] == nil {
            let store = OpaqueOperationStore(erasing: store)
            change.storesAdded.update(store)
            stores.update(store)
          }
        }
        for store in beforeEntries {
          if afterEntries[store.path] == nil {
            change.storesRemoved.update(OpaqueOperationStore(erasing: store))
            stores.removeValue(forPath: store.path)
          }
        }
        state.sendSubscriptionChange(change: change)
        return value
      }
    }
  }
}

// MARK: - Subscribe

extension OperationClient {
  /// A description of stores added to and removed from an ``OperationClient`` subscription.
  public struct OpaqueSubscriptionChange: Sendable {
    /// Stores added to the client during this change.
    public fileprivate(set) var storesAdded = OperationPathableCollection<OpaqueOperationStore>()

    /// Stores removed from the client during this change.
    public fileprivate(set) var storesRemoved = OperationPathableCollection<OpaqueOperationStore>()

    fileprivate var isEmpty: Bool {
      self.storesAdded.isEmpty && self.storesRemoved.isEmpty
    }
  }

  /// Subscribes to stores being added to and removed from this client.
  ///
  /// The subscription is scoped to stores whose paths match the specified path prefix.
  ///
  /// ```swift
  /// let subscription = client.subscribe(matching: ["users"]) { change in
  ///   for store in change.storesAdded {
  ///     print("Added store at path: \(store.path)")
  ///   }
  ///   for store in change.storesRemoved {
  ///     print("Removed store at path: \(store.path)")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - path: A path prefix used to filter which store changes are observed.
  ///   - onChange: A closure invoked whenever matching stores are added or removed.
  /// - Returns: An ``OperationSubscription``.
  public func subscribe(
    matching path: OperationPath = OperationPath(),
    onChange: @Sendable @escaping (OpaqueSubscriptionChange) -> Void
  ) -> OperationSubscription {
    self.state.withLock { state in
      let subscription = State.Subscription(handler: onChange, matchablePath: path)
      return state.subscriptions.add(handler: subscription).subscription
    }
  }

  /// A description of typed stores added to and removed from an ``OperationClient`` subscription.
  public struct SubscriptionChange<State: OperationState & Sendable>: Sendable {
    /// Stores of the subscribed state type added to the client during this change.
    public let storesAdded: OperationPathableCollection<OperationStore<State>>

    /// Stores of the subscribed state type removed from the client during this change.
    public let storesRemoved: OperationPathableCollection<OperationStore<State>>

    fileprivate var isEmpty: Bool {
      self.storesAdded.isEmpty && self.storesRemoved.isEmpty
    }
  }

  /// Subscribes to stores of a specific state type being added to and removed from this client.
  ///
  /// The subscription is scoped to stores whose paths match the specified path prefix, and only
  /// stores of the requested state type are included in the emitted change.
  ///
  /// ```swift
  /// let subscription = client.subscribe(
  ///   matching: ["users"],
  ///   state: QueryState<User, any Error>.self
  /// ) { change in
  ///   for store in change.storesAdded {
  ///     print("Added user store at path: \(store.path)")
  ///   }
  ///   for store in change.storesRemoved {
  ///     print("Removed user store at path: \(store.path)")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - path: A path prefix used to filter which store changes are observed.
  ///   - state: The state type of stores to observe.
  ///   - onChange: A closure invoked whenever matching stores of the specified state type are added
  ///     or removed.
  /// - Returns: An ``OperationSubscription``.
  public func subscribe<State: OperationState>(
    matching path: OperationPath = OperationPath(),
    state: State.Type,
    onChange: @Sendable @escaping (SubscriptionChange<State>) -> Void
  ) -> OperationSubscription {
    self.subscribe(matching: path) { change in
      let change = SubscriptionChange(
        storesAdded: OperationPathableCollection(
          change.storesAdded.compactMap { $0.base as? OperationStore<State> }
        ),
        storesRemoved: OperationPathableCollection(
          change.storesRemoved.compactMap { $0.base as? OperationStore<State> }
        )
      )
      guard !change.isEmpty else { return }
      onChange(change)
    }
  }
}

// MARK: - CreateStore Helper

extension OperationClient {
  private func createStore(in state: State) -> CreateStore {
    CreateStore(
      creator: self.storeCreator,
      initialContext: state.initialContext,
      operationTypes: MutableBox(value: state.operationTypes)
    )
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationClient`` in this context.
  ///
  /// By default, the client is nil. When initializing an ``OperationClient``, this property will be
  /// set to the initialized client, and will become nil when the client is deinitialized.
  ///
  /// ``OperationStore`` instances retrieved through an `OperationClient` will have this property set to
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
