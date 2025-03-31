#if canImport(SwiftUI)
  import SwiftUI
  import QueryCore
  import IdentifiedCollections

  extension State where Value: QueryStateProtocol {
    @propertyWrapper
    @dynamicMemberLookup
    public struct Query<Request: QueryRequest>: Sendable
    where Request.Value == Request.State.QueryValue, Value == Request.State {
      private let query: Request
      private let clientOverride: QueryClient?

      @SwiftUI.State private var state: Value

      @Environment(\.queryClient) private var queryClient

      private var subscription = QuerySubscription.empty
      private var previousClient: QueryClient?

      public var wrappedValue: Value {
        self.state
      }

      public var projectedValue: Self {
        get { self }
        set { self = newValue }
      }

      private init(query: Request, initialState: Value, clientOverride: QueryClient?) {
        self.query = query
        self.clientOverride = clientOverride
        self._state = State(initialValue: initialState)
      }
    }
  }

  // MARK: - Query Init

  extension State.Query {
    public init(wrappedValue: Value, query: Request, client: QueryClient? = nil) {
      self.init(query: query, initialState: wrappedValue, clientOverride: client)
    }

    public init<V>(query: Request, initialValue: V? = nil, client: QueryClient? = nil)
    where Request.Value == V, Value == QueryState<V?, V> {
      self.init(
        query: query,
        initialState: QueryState(initialValue: initialValue),
        clientOverride: client
      )
    }

    public init<Query: QueryRequest>(query: DefaultQuery<Query>, client: QueryClient? = nil)
    where Value == QueryState<Query.Value, Query.Value>, Request == DefaultQuery<Query> {
      self.init(
        query: query,
        initialState: QueryState(initialValue: query.defaultValue),
        clientOverride: client
      )
    }

    public init(query: Request, client: QueryClient? = nil) where Request: InfiniteQueryRequest {
      self.init(
        query: query,
        initialState: InfiniteQueryState(initialValue: [], initialPageId: query.initialPageId),
        clientOverride: client
      )
    }

    public init<Arguments: Sendable, V: Sendable>(mutation: Request, client: QueryClient? = nil)
    where Request: MutationRequest<Arguments, V> {
      self.init(query: mutation, initialState: MutationState(), clientOverride: client)
    }
  }

  // MARK: - Store

  extension State.Query {
    public var store: QueryStore<Value> {
      self.client.store(for: self.query, initialState: self.state)
    }
  }

  // MARK: - QueryClient

  extension State.Query {
    public var client: QueryClient {
      self.clientOverride ?? self.queryClient
    }
  }

  // MARK: - DynamicProperty

  extension State.Query: DynamicProperty {
    public mutating func update() {
      defer { self.previousClient = self.client }
      if self.previousClient == nil || self.previousClient !== self.client {
        self.subscription.cancel()
        self.subscription = self.store.subscribe(
          with: QueryEventHandler { [self] state, _ in
            Task { self.state = state }
          }
        )
        self.state = self.store.state
      }
    }
  }

  // MARK: - Dynamic Member Lookup

  extension State.Query {
    public var currentValue: Value.StateValue {
      get { self.state.currentValue }
      nonmutating set { self.store.currentValue = newValue }
    }

    public subscript<V>(dynamicMember keyPath: KeyPath<Value, V>) -> V {
      self.state[keyPath: keyPath]
    }

    public subscript<V>(dynamicMember keyPath: KeyPath<QueryStore<Value>, V>) -> V {
      self.store[keyPath: keyPath]
    }
  }

  // MARK: - State Functions

  extension State.Query {
    public func setResult(
      to result: Result<Value.StateValue, any Error>,
      using context: QueryContext? = nil
    ) {
      self.store.setResult(to: result, using: context)
    }

    public func reset(using context: QueryContext? = nil) {
      self.store.reset(using: context)
    }
  }

  // MARK: - Is Stale

  extension State.Query {
    public func isStale(using context: QueryContext? = nil) -> Bool {
      self.store.isStale(using: context)
    }
  }

  // MARK: - Fetch

  extension State.Query {
    @discardableResult
    public func fetch(
      using configuration: QueryTaskConfiguration? = nil,
      handler: QueryEventHandler<Value> = QueryEventHandler()
    ) async throws -> Value.QueryValue {
      try await self.store.fetch(using: configuration, handler: handler)
    }

    public func fetchTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<Value.QueryValue> {
      self.store.fetchTask(using: configuration)
    }
  }

  extension State.Query where Value: _InfiniteQueryStateProtocol {
    @discardableResult
    public func fetchAllPages(
      using configuration: QueryTaskConfiguration? = nil,
      handler: InfiniteQueryEventHandler<Value.PageID, Value.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPages<Value.PageID, Value.PageValue> {
      try await self.store.fetchAllPages(using: configuration, handler: handler)
    }

    public func fetchAllPagesTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<InfiniteQueryPages<Value.PageID, Value.PageValue>> {
      self.store.fetchAllPagesTask(using: configuration)
    }

    @discardableResult
    public func fetchNextPage(
      using configuration: QueryTaskConfiguration? = nil,
      handler: InfiniteQueryEventHandler<Value.PageID, Value.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<Value.PageID, Value.PageValue>? {
      try await self.store.fetchNextPage(using: configuration, handler: handler)
    }

    public func fetchNextPageTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<InfiniteQueryPage<Value.PageID, Value.PageValue>?> {
      self.store.fetchNextPageTask(using: configuration)
    }

    @discardableResult
    public func fetchPreviousPage(
      using configuration: QueryTaskConfiguration? = nil,
      handler: InfiniteQueryEventHandler<Value.PageID, Value.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<Value.PageID, Value.PageValue>? {
      try await self.store.fetchPreviousPage(using: configuration, handler: handler)
    }

    public func fetchPreviousPageTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<InfiniteQueryPage<Value.PageID, Value.PageValue>?> {
      self.store.fetchPreviousPageTask(using: configuration)
    }
  }

  extension State.Query where Value: _MutationStateProtocol {
    @discardableResult
    public func mutate(
      with arguments: Value.Arguments,
      using configuration: QueryTaskConfiguration? = nil,
      handler: MutationEventHandler<Value.Arguments, Value.Value> = MutationEventHandler()
    ) async throws -> Value.Value {
      try await self.store.mutate(with: arguments, using: configuration, handler: handler)
    }

    public func mutateTask(
      with arguments: Value.Arguments,
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<Value.Value> {
      self.store.mutateTask(with: arguments, using: configuration)
    }

    @discardableResult
    public func retryLatest(
      using configuration: QueryTaskConfiguration? = nil,
      handler: MutationEventHandler<Value.Arguments, Value.Value> = MutationEventHandler()
    ) async throws -> Value.Value {
      try await self.store.retryLatest(using: configuration, handler: handler)
    }

    public func retryLatestTask(
      using configuration: QueryTaskConfiguration? = nil
    ) -> QueryTask<Value.Value> {
      self.store.retryLatestTask(using: configuration)
    }
  }
#endif
