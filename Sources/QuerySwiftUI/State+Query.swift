#if canImport(SwiftUI)
  import SwiftUI
  import QueryCore
  import IdentifiedCollections

  extension State where Value: QueryStateProtocol {
    @propertyWrapper
    @dynamicMemberLookup
    public struct Query: DynamicProperty, Sendable {
      @SwiftUI.State private var state: Value

      @Environment(\.queryClient) var queryClient
      public let store: QueryStore<Value>

      public var wrappedValue: Value {
        self.state
      }

      public var projectedValue: Self {
        get { self }
        set { self = newValue }
      }

      public init(store: QueryStore<Value>) {
        self.store = store
        self._state = SwiftUI.State(initialValue: store.state)
      }

      public init<Query: QueryRequest>(
        query: Query,
        client: QueryClient? = nil
      )
      where
        Query.State == QueryState<Query.Value?, Query.Value>,
        Value == QueryState<Query.Value?, Query.Value>
      {
        @Environment(\.queryClient) var queryClient
        self.init(store: (client ?? queryClient).store(for: query))
      }

      public init<Query: QueryRequest>(
        wrappedValue: Value,
        query: Query,
        client: QueryClient? = nil
      )
      where Query.State.QueryValue == Query.Value, Value == Query.State {
        @Environment(\.queryClient) var queryClient
        self.init(store: (client ?? queryClient).store(for: query, initialState: wrappedValue))
      }

      public init<Query: QueryRequest>(
        query: DefaultQuery<Query>,
        client: QueryClient? = nil
      )
      where
        Query.State == QueryState<Query.Value, Query.Value>,
        Value == QueryState<Query.Value, Query.Value>
      {
        @Environment(\.queryClient) var queryClient
        self.init(store: (client ?? queryClient).store(for: query))
      }

      public init<Query: InfiniteQueryRequest>(
        query: Query,
        client: QueryClient? = nil
      ) where Value == Query.State {
        @Environment(\.queryClient) var queryClient
        self.init(store: (client ?? queryClient).store(for: query))
      }

      public init<Arguments: Sendable, V: Sendable, Query: MutationRequest<Arguments, V>>(
        query: Query,
        client: QueryClient? = nil
      ) where Value == MutationState<Arguments, V> {
        @Environment(\.queryClient) var queryClient
        self.init(store: (client ?? queryClient).store(for: query))
      }
    }
  }

  // MARK: - Query Init

  extension State.Query {

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
