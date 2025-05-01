import Dependencies
import Query
import Sharing

// MARK: - SharedQuery

@propertyWrapper
@dynamicMemberLookup
public struct SharedQuery<State: QueryStateProtocol>: Sendable {
  @Shared var value: QueryStateKeyValue<State>

  public var wrappedValue: State.StateValue {
    get { self.value.currentValue }
    @available(
      *,
      unavailable,
      message: "Use '$shared.withLock' to modify a shared query value with exclusive access."
    )
    nonmutating set {
      self.withLock { $0 = newValue }
    }
  }

  public var projectedValue: Self {
    get { self }
    nonmutating set { self.$value = newValue.$value }
  }
}

// MARK: - Store Initializer

extension SharedQuery {
  public init(store: QueryStore<State>, scheduler: some SharedQueryStateScheduler = .synchronous) {
    self._value = Shared(
      wrappedValue: QueryStateKeyValue(store: store),
      QueryStateKey(store: store, scheduler: scheduler)
    )
  }
}

// MARK: - QueryState Initializer

extension SharedQuery {
  public init<Query: QueryRequest>(
    _ query: Query,
    initialState: Query.State,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == Query.State {
    @Dependency(\.defaultQueryClient) var queryClient
    self.init(
      store: (client ?? queryClient).store(for: query, initialState: initialState),
      scheduler: scheduler
    )
  }
}

// MARK: - Shared Properties

extension SharedQuery {
  public func load() async throws {
    try await self.fetch()
  }

  public func withLock<R>(
    _ operation: (inout State.StateValue) throws -> R,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) rethrows -> R {
    try self.$value.withLock { try operation(&$0.currentValue) }
  }
}

// MARK: - Shared

extension SharedQuery {
  public var shared: Shared<State.StateValue> {
    self.$value.currentValue
  }

  public var sharedReader: SharedReader<State.StateValue> {
    self.$value.currentValue
  }
}

// MARK: - Dynamic Member Lookup

extension SharedQuery {
  public subscript<Value: Sendable>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.value.store.state[keyPath: keyPath]
  }

  public subscript<Value: Sendable>(
    dynamicMember keyPath: KeyPath<QueryStore<State>, Value>
  ) -> Value {
    self.value.store[keyPath: keyPath]
  }

  public subscript<Value: Sendable>(
    dynamicMember keyPath: ReferenceWritableKeyPath<QueryStore<State>, Value>
  ) -> Value {
    get { self.value.store[keyPath: keyPath] }
    set { self.value.store[keyPath: keyPath] = newValue }
  }

  public subscript<Value: Sendable>(
    dynamicMember keyPath: KeyPath<State.StateValue, Value>
  ) -> SharedReader<Value> {
    self.shared[dynamicMember: keyPath]
  }

  public subscript<Value: Sendable>(
    dynamicMember keyPath: WritableKeyPath<State.StateValue, Value>
  ) -> Shared<Value> {
    self.shared[dynamicMember: keyPath]
  }
}

// MARK: - Fetch

extension SharedQuery {
  @discardableResult
  public func fetch(
    using configuration: QueryTaskConfiguration? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws -> State.QueryValue {
    try await self.value.store.fetch(using: configuration, handler: handler)
  }

  @discardableResult
  public func fetchTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.QueryValue> {
    self.value.store.fetchTask(using: configuration)
  }
}

// MARK: - Reset

extension SharedQuery {
  public func reset(using context: QueryContext? = nil) {
    self.value.store.reset(using: context)
  }
}

// MARK: - Set Result

extension SharedQuery {
  public func setResult(
    to result: Result<State.StateValue, any Error>,
    using context: QueryContext? = nil
  ) {
    self.value.store.setResult(to: result, using: context)
  }
}

// MARK: - Equatable

extension SharedQuery: Equatable where State.StateValue: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.value.currentValue == rhs.value.currentValue
  }
}

// MARK: - Queries

extension SharedQuery {
  public init<Value: Sendable, Query: QueryRequest<Value, QueryState<Value?, Value>>>(
    wrappedValue: Query.State.StateValue = nil,
    _ query: Query,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == Query.State {
    self.init(
      query,
      initialState: QueryState(initialValue: wrappedValue),
      client: client,
      scheduler: scheduler
    )
  }

  public init<Query: QueryRequest>(
    _ query: DefaultQuery<Query>,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == DefaultQuery<Query>.State {
    self.init(
      query,
      initialState: QueryState(initialValue: query.defaultValue),
      client: client,
      scheduler: scheduler
    )
  }
}

// MARK: - InfiniteQueries

extension SharedQuery {
  public init<Query: InfiniteQueryRequest>(
    wrappedValue: Query.State.StateValue = [],
    _ query: Query,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
    self.init(
      query,
      initialState: InfiniteQueryState(
        initialValue: wrappedValue,
        initialPageId: query.initialPageId
      ),
      client: client,
      scheduler: scheduler
    )
  }

  public init<Query: InfiniteQueryRequest>(
    _ query: DefaultInfiniteQuery<Query>,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
    self.init(
      query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      ),
      client: client,
      scheduler: scheduler
    )
  }
}

extension SharedQuery where State: _InfiniteQueryStateProtocol {
  @discardableResult
  public func fetchAllPages(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
    try await self.value.store.fetchAllPages(using: configuration, handler: handler)
  }

  public func fetchAllPagesTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPages<State.PageID, State.PageValue>> {
    self.value.store.fetchAllPagesTask(using: configuration)
  }

  @discardableResult
  public func fetchNextPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    try await self.value.store.fetchNextPage(using: configuration, handler: handler)
  }

  public func fetchNextPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    self.value.store.fetchNextPageTask(using: configuration)
  }

  @discardableResult
  public func fetchPreviousPage(
    using configuration: QueryTaskConfiguration? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    try await self.value.store.fetchPreviousPage(using: configuration, handler: handler)
  }

  public func fetchPreviousPageTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    self.value.store.fetchPreviousPageTask(using: configuration)
  }
}

// MARK: - Mutations

extension SharedQuery {
  public init<
    Arguments: Sendable,
    Value: Sendable,
    Mutation: MutationRequest<Arguments, Value>
  >(
    _ mutation: Mutation,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  )
  where State == MutationState<Arguments, Value> {
    self.init(mutation, initialState: MutationState(), client: client, scheduler: scheduler)
  }
}

extension SharedQuery where State: _MutationStateProtocol {
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.value.store.mutate(with: arguments, using: configuration, handler: handler)
  }

  public func mutateTask(
    with arguments: State.Arguments,
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.value.store.mutateTask(with: arguments, using: configuration)
  }

  @discardableResult
  public func retryLatest(
    using configuration: QueryTaskConfiguration? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.value.store.retryLatest(using: configuration, handler: handler)
  }

  public func retryLatestTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<State.Value> {
    self.value.store.retryLatestTask(using: configuration)
  }
}
