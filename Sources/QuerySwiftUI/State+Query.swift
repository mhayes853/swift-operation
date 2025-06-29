#if canImport(SwiftUI)
  import SwiftUI
  import IdentifiedCollections

  extension State {
    @MainActor
    @propertyWrapper
    @dynamicMemberLookup
    public struct Query<State: QueryStateProtocol> where Value == State.StateValue {
      @SwiftUI.State var state: State

      @Environment(\.queryClient) private var queryClient

      private let _store: @Sendable (QueryClient) -> QueryStore<State>
      private let transaction: MainActorTransaction
      private var subscription = QuerySubscription.empty
      private var previousStore: QueryStore<State>?

      public var wrappedValue: Value {
        get { self.state.currentValue }
        nonmutating set { self.store.currentValue = newValue }
      }

      public var projectedValue: Self {
        get { self }
        set { self = newValue }
      }

      public init(store: QueryStore<State>, transaction: Transaction? = nil) {
        self._store = { _ in store }
        self._state = SwiftUI.State(initialValue: store.state)
        self.transaction = MainActorTransaction(transaction: transaction)
      }

      public init<Query: QueryRequest>(
        _ query: Query,
        initialState: Query.State,
        client: QueryClient? = nil,
        transaction: Transaction? = nil
      ) where State == Query.State {
        self._store = { (client ?? $0).store(for: query, initialState: initialState) }
        self._state = SwiftUI.State(initialValue: initialState)
        self.transaction = MainActorTransaction(transaction: transaction)
      }
    }
  }

  // MARK: - Store Inits

  extension State.Query {
    public init(store: QueryStore<State>, animation: Animation) {
      self.init(store: store, transaction: Transaction(animation: animation))
    }
  }

  // MARK: - Query Init

  extension State.Query {
    public init<V: Sendable, Query: QueryRequest<V, QueryState<V?, V>>>(
      wrappedValue: Value = nil,
      _ query: Query,
      client: QueryClient? = nil,
      transaction: Transaction? = nil
    ) where State == Query.State {
      self.init(
        query,
        initialState: QueryState(initialValue: wrappedValue),
        client: client,
        transaction: transaction
      )
    }

    public init<V: Sendable, Query: QueryRequest<V, QueryState<V?, V>>>(
      wrappedValue: Value = nil,
      _ query: Query,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == Query.State {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        transaction: Transaction(animation: animation)
      )
    }

    public init<Query: QueryRequest>(
      _ query: DefaultQuery<Query>,
      client: QueryClient? = nil,
      transaction: Transaction? = nil
    ) where State == DefaultQuery<Query>.State {
      self.init(
        query,
        initialState: QueryState(initialValue: query.defaultValue),
        client: client,
        transaction: transaction
      )
    }

    public init<Query: QueryRequest>(
      _ query: DefaultQuery<Query>,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == DefaultQuery<Query>.State {
      self.init(
        query,
        initialState: QueryState(initialValue: query.defaultValue),
        client: client,
        transaction: Transaction(animation: animation)
      )
    }
  }

  // MARK: - Store

  extension State.Query {
    public var store: QueryStore<State> {
      self._store(self.queryClient)
    }
  }

  // MARK: - Exclusive Access

  extension State.Query {
    /// Exclusively accesses the query properties inside the specified closure.
    ///
    /// The property-wrapper is thread-safe due to the thread-safety of the underlying `QueryStore`,
    /// but accessing individual properties without exclusive access can still lead to high-level
    /// data races. Use this method to ensure that your code has exclusive access to the store when
    /// performing multiple property accesses to compute a value or modify the underlying store.
    ///
    /// ```swift
    /// @State.Query<QueryState<Int, Int>> var value
    ///
    /// // 🔴 Is prone to high-level data races.
    /// $value.currentValue += 1
    ///
    //  // ✅ No data races.
    /// $value.withExclusiveAccess {
    ///   $value.currentValue += 1
    /// }
    /// ```
    ///
    /// - Parameter fn: A closure with exclusive access to the properties of this property wrapper.
    /// - Returns: Whatever `fn` returns.
    public func withExclusiveAccess<T>(_ fn: () throws -> sending T) rethrows -> sending T {
      try self.store.withExclusiveAccess(fn)
    }
  }

  // MARK: - DynamicProperty

  extension State.Query: @preconcurrency DynamicProperty {
    public mutating func update() {
      defer { self.previousStore = self.store }
      guard self.subscription == .empty || self.previousStore !== self.store else { return }
      self.subscription.cancel()
      let stateValue = self._state
      let transaction = self.transaction
      self.subscription = self.store.subscribe(
        with: QueryEventHandler { state, _ in
          Task { @MainActor in
            withTransaction(transaction) { stateValue.wrappedValue = state }
          }
        }
      )
    }
  }

  // MARK: - Dynamic Member Lookup

  extension State.Query {
    public subscript<V>(dynamicMember keyPath: KeyPath<State, V>) -> V {
      self.state[keyPath: keyPath]
    }

    public subscript<V>(dynamicMember keyPath: KeyPath<QueryStore<State>, V>) -> V {
      self.store[keyPath: keyPath]
    }

    public subscript<V>(
      dynamicMember keyPath: ReferenceWritableKeyPath<QueryStore<State>, V>
    ) -> V {
      get { self.store[keyPath: keyPath] }
      set { self.store[keyPath: keyPath] = newValue }
    }
  }

  // MARK: - State Functions

  extension State.Query {
    public func setResult(
      to result: Result<Value, any Error>,
      using context: QueryContext? = nil
    ) {
      self.store.setResult(to: result, using: context)
    }

    public func resetState(using context: QueryContext? = nil) {
      self.store.resetState(using: context)
    }
  }

  // MARK: - Fetch

  extension State.Query {
    @discardableResult
    public func fetch(
      using context: QueryContext? = nil,
      handler: QueryEventHandler<State> = QueryEventHandler()
    ) async throws -> State.QueryValue {
      try await self.store.fetch(using: context, handler: handler)
    }

    public func fetchTask(using context: QueryContext? = nil) -> QueryTask<State.QueryValue> {
      self.store.fetchTask(using: context)
    }
  }

  // MARK: - Infinite Queries

  extension State.Query {
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: QueryClient? = nil,
      transaction: Transaction?
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        query,
        initialState: InfiniteQueryState(
          initialValue: wrappedValue,
          initialPageId: query.initialPageId
        ),
        client: client,
        transaction: transaction
      )
    }

    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        query,
        initialState: InfiniteQueryState(
          initialValue: wrappedValue,
          initialPageId: query.initialPageId
        ),
        client: client,
        transaction: Transaction(animation: animation)
      )
    }

    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: QueryClient? = nil,
      transaction: Transaction? = nil
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        query,
        initialState: InfiniteQueryState(
          initialValue: query.defaultValue,
          initialPageId: query.initialPageId
        ),
        client: client,
        transaction: transaction
      )
    }

    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        query,
        initialState: InfiniteQueryState(
          initialValue: query.defaultValue,
          initialPageId: query.initialPageId
        ),
        client: client,
        transaction: Transaction(animation: animation)
      )
    }
  }

  extension State.Query where State: _InfiniteQueryStateProtocol {
    @discardableResult
    public func refetchAllPages(
      using context: QueryContext? = nil,
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
      try await self.store.refetchAllPages(using: context, handler: handler)
    }

    public func refetchAllPagesTask(
      using context: QueryContext? = nil
    ) -> QueryTask<InfiniteQueryPages<State.PageID, State.PageValue>> {
      self.store.refetchAllPagesTask(using: context)
    }

    @discardableResult
    public func fetchNextPage(
      using context: QueryContext? = nil,
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchNextPage(using: context, handler: handler)
    }

    public func fetchNextPageTask(
      using context: QueryContext? = nil
    ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
      self.store.fetchNextPageTask(using: context)
    }

    @discardableResult
    public func fetchPreviousPage(
      using context: QueryContext? = nil,
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchPreviousPage(using: context, handler: handler)
    }

    public func fetchPreviousPageTask(
      using context: QueryContext? = nil
    ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
      self.store.fetchPreviousPageTask(using: context)
    }
  }

  // MARK: - Mutations

  extension State.Query {
    public init<
      Arguments: Sendable,
      V: Sendable,
      Mutation: MutationRequest<Arguments, V>
    >(
      wrappedValue: V?,
      _ mutation: Mutation,
      client: QueryClient? = nil,
      transaction: Transaction? = nil
    ) where State == MutationState<Arguments, V> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        transaction: transaction
      )
    }

    public init<
      Arguments: Sendable,
      V: Sendable,
      Mutation: MutationRequest<Arguments, V>
    >(
      wrappedValue: V?,
      _ mutation: Mutation,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == MutationState<Arguments, V> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        transaction: Transaction(animation: animation)
      )
    }

    public init<
      Arguments: Sendable,
      V: Sendable,
      Mutation: MutationRequest<Arguments, V>
    >(
      _ mutation: Mutation,
      client: QueryClient? = nil,
      transaction: Transaction? = nil
    ) where State == MutationState<Arguments, V> {
      self.init(
        mutation,
        initialState: MutationState(),
        client: client,
        transaction: transaction
      )
    }

    public init<
      Arguments: Sendable,
      V: Sendable,
      Mutation: MutationRequest<Arguments, V>
    >(
      _ mutation: Mutation,
      client: QueryClient? = nil,
      animation: Animation
    ) where State == MutationState<Arguments, V> {
      self.init(
        mutation,
        initialState: MutationState(),
        client: client,
        transaction: Transaction(animation: animation)
      )
    }
  }

  extension State.Query where State: _MutationStateProtocol {
    @discardableResult
    public func mutate(
      with arguments: State.Arguments,
      using context: QueryContext? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.mutate(with: arguments, using: context, handler: handler)
    }

    public func mutateTask(
      with arguments: State.Arguments,
      using context: QueryContext? = nil
    ) -> QueryTask<State.Value> {
      self.store.mutateTask(with: arguments, using: context)
    }

    @discardableResult
    public func retryLatest(
      using context: QueryContext? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.retryLatest(using: context, handler: handler)
    }

    public func retryLatestTask(using context: QueryContext? = nil) -> QueryTask<State.Value> {
      self.store.retryLatestTask(using: context)
    }
  }

  extension State.Query where State: _MutationStateProtocol, State.Arguments == Void {
    @discardableResult
    public func mutate(
      using context: QueryContext? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.mutate(using: context, handler: handler)
    }

    public func mutateTask(using context: QueryContext? = nil) -> QueryTask<State.Value> {
      self.store.mutateTask(using: context)
    }
  }
#endif
