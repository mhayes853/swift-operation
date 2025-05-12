#if canImport(SwiftUI)
  import SwiftUI
  import IdentifiedCollections

  extension State {
    @MainActor
    @propertyWrapper
    @dynamicMemberLookup
    public struct Query<State: QueryStateProtocol> where Value == State.StateValue {
      @SwiftUI.State private var state: State

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
  }

  // MARK: - Store

  extension State.Query {
    public var store: QueryStore<State> {
      self._store(self.queryClient)
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
      using configuration: QueryTaskConfiguration? = nil,
      handler: QueryEventHandler<State> = QueryEventHandler()
    ) async throws -> State.QueryValue {
      try await self.store.fetch(using: configuration, handler: handler)
    }

    public func fetchTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<State.QueryValue> {
      self.store.fetchTask(using: configuration)
    }
  }

  // MARK: - Infinite Queries

  extension State.Query where State: _InfiniteQueryStateProtocol {
    @discardableResult
    public func fetchAllPages(
      using configuration: QueryTaskConfiguration? = nil,
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
      try await self.store.fetchAllPages(using: configuration, handler: handler)
    }

    public func fetchAllPagesTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<InfiniteQueryPages<State.PageID, State.PageValue>> {
      self.store.fetchAllPagesTask(using: configuration)
    }

    @discardableResult
    public func fetchNextPage(
      using configuration: QueryTaskConfiguration? = nil,
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchNextPage(using: configuration, handler: handler)
    }

    public func fetchNextPageTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
      self.store.fetchNextPageTask(using: configuration)
    }

    @discardableResult
    public func fetchPreviousPage(
      using configuration: QueryTaskConfiguration? = nil,
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchPreviousPage(using: configuration, handler: handler)
    }

    public func fetchPreviousPageTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
      self.store.fetchPreviousPageTask(using: configuration)
    }
  }

  // MARK: - Mutations

  extension State.Query where State: _MutationStateProtocol {
    @discardableResult
    public func mutate(
      with arguments: State.Arguments,
      using configuration: QueryTaskConfiguration? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.mutate(with: arguments, using: configuration, handler: handler)
    }

    public func mutateTask(
      with arguments: State.Arguments,
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<State.Value> {
      self.store.mutateTask(with: arguments, using: configuration)
    }

    @discardableResult
    public func retryLatest(
      using configuration: QueryTaskConfiguration? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.retryLatest(using: configuration, handler: handler)
    }

    public func retryLatestTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<State.Value> {
      self.store.retryLatestTask(using: configuration)
    }
  }

  extension State.Query where State: _MutationStateProtocol, State.Arguments == Void {
    @discardableResult
    public func mutate(
      using configuration: QueryTaskConfiguration? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.mutate(using: configuration, handler: handler)
    }

    public func mutateTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<State.Value> {
      self.store.mutateTask(using: configuration)
    }
  }
#endif
