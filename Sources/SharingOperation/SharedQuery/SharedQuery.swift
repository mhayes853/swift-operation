import Dependencies
import Operation
import Sharing

// MARK: - SharedQuery

/// A property wrapper for observing the state and interacting with a `QueryRequest`.
///
/// ```swift
/// import SharingOperation
///
/// // This will begin fetching the post.
/// @SharedQuery(Post.query(for: 1)) var post
///
/// if $post.isLoading {
///   print("Loading")
/// } else if let error = $post.error {
///   print("Error", error)
/// } else {
///   print("Post", post)
/// }
/// ```
///
/// You can also access all properties and methods to interact with the query that come through
/// `QueryStore` on the projected value of this property wrapper.
///
/// ```swift
/// try await $post.fetch()
/// $post.setResult(to: .failure(SomeError()))
/// // ...
/// ```
///
/// When modifying the current value of the query, use ``withLock(_:fileID:filePath:line:column:)``
/// as if it were a normal `@Shared` property.
///
/// ```swift
/// $post.withLock { post in
///   // Mutate the post...
/// }
/// ```
@propertyWrapper
@dynamicMemberLookup
public struct SharedQuery<State: QueryStateProtocol>: Sendable {
  @Shared var value: QueryStateKeyValue<State>

  /// Whether or not this shared query is backed by a user specified `QueryRequest`.
  ///
  /// This property is true if this shared query was not created with a `QueryRequest` through
  /// ``init(initialState:)``.
  public private(set) var isBacked = true

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

  /// Creates an unbacked shared query.
  ///
  /// - Parameter initialState: The initial state of the query.
  public init(initialState: State) {
    self._value = Shared(
      value: QueryStateKeyValue(
        store: .detached(query: UnbackedQuery(), initialState: initialState)
      )
    )
    self.isBacked = false
  }
}

// MARK: - Unbacked Initializers

extension SharedQuery {
  /// Creates an unbacked shared query.
  ///
  /// - Parameter wrappedValue: The initial value of the query.
  public init<Value: Sendable>(
    wrappedValue: State.StateValue = nil
  ) where State == QueryState<Value?, Value> {
    self.init(initialState: QueryState(initialValue: wrappedValue))
  }

  /// Creates an unbacked shared query.
  ///
  /// - Parameter wrappedValue: The initial value of the query.
  public init<Value: Sendable>(
    wrappedValue: State.StateValue
  ) where State == QueryState<Value, Value> {
    self.init(initialState: QueryState(initialValue: wrappedValue))
  }

  /// Creates an unbacked shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value of the query.
  ///   - initialPageId: The initial page id of the query.
  public init<PageID, PageValue>(
    wrappedValue: State.StateValue,
    initialPageId: PageID
  ) where State == InfiniteQueryState<PageID, PageValue> {
    self.init(
      initialState: InfiniteQueryState(initialValue: wrappedValue, initialPageId: initialPageId)
    )
  }

  /// Creates an unbacked shared query.
  ///
  /// - Parameter wrappedValue: The initial value of the query.
  public init<Arguments, ReturnValue>(
    wrappedValue: State.StateValue
  ) where State == MutationState<Arguments, ReturnValue> {
    self.init(initialState: MutationState(initialValue: wrappedValue))
  }
}

// MARK: - Store Initializer

extension SharedQuery {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - store: The `QueryStore` to subscribe to.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
  public init(store: QueryStore<State>, scheduler: some SharedQueryStateScheduler = .synchronous) {
    self._value = Shared(
      wrappedValue: QueryStateKeyValue(store: store),
      QueryStateKey(store: store, scheduler: scheduler)
    )
  }
}

// MARK: - QueryState Initializer

extension SharedQuery {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - query: The `QueryRequest`.
  ///   - initialState: The initial state.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
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
  /// Loads the data from this query.
  public func load() async throws {
    try await self.fetch()
  }

  /// Perform an operation on shared state with isolated access to the underlying value.
  ///
  /// - Parameters
  ///   - operation: An operation given mutable, isolated access to the underlying shared value.
  ///   - fileID: The source `#fileID` associated with the lock.
  ///   - filePath: The source `#filePath` associated with the lock.
  ///   - line: The source `#line` associated with the lock.
  ///   - column: The source `#column` associated with the lock.
  /// - Returns: The value returned from `operation`.
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
  /// The underyling `Shared` powering the property wrapper.
  public var shared: Shared<State.StateValue> {
    self.$value.currentValue
  }

  /// The underyling `SharedReader` powering the property wrapper.
  public var sharedReader: SharedReader<State.StateValue> {
    self.$value.currentValue
  }
}

// MARK: - Exclusive Access

extension SharedQuery {
  /// Exclusively accesses the query properties inside the specified closure.
  ///
  /// The property-wrapper is thread-safe due to the thread-safety of the underlying `QueryStore`,
  /// but accessing individual properties without exclusive access can still lead to high-level
  /// data races. Use this method to ensure that your code has exclusive access to the store when
  /// performing multiple property accesses to compute a value or modify the underlying store.
  ///
  /// ```swift
  /// @SharedQuery<QueryState<Int, Int>> var value
  ///
  /// // 🔴 Is prone to high-level data races.
  /// $value.currentValue += 1
  ///
  ///  // ✅ No data races.
  /// $value.withExclusiveAccess {
  ///   $0.currentValue += 1
  /// }
  /// ```
  ///
  /// - Parameter fn: A closure with exclusive access to the properties of this property wrapper.
  /// - Returns: Whatever `fn` returns.
  public func withExclusiveAccess<T>(
    _ fn: (Self) throws -> sending T
  ) rethrows -> sending T {
    try self.store.withExclusiveAccess { _ in try fn(self) }
  }
}

// MARK: - Store

extension SharedQuery {
  /// The backing `QueryStore` for this shared query.
  public var store: QueryStore<State> {
    self.value.store
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
  /// Fetches the query's data.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  ///   - handler: A `QueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func fetch(
    using context: QueryContext? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws -> State.QueryValue {
    try await self.value.store.fetch(using: context, handler: handler)
  }

  /// Creates a `QueryTask` to fetch the query's data.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameter context: The `QueryContext` for the task.
  /// - Returns: A task to fetch the query's data.
  @discardableResult
  public func fetchTask(using context: QueryContext? = nil) -> QueryTask<State.QueryValue> {
    self.value.store.fetchTask(using: context)
  }
}

// MARK: - Reset

extension SharedQuery {
  /// Resets the state of the query to its original values.
  ///
  /// > Important: This will cancel all active `QueryTask`s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The `QueryContext` to reset the query in.
  public func resetState(using context: QueryContext? = nil) {
    self.value.store.resetState(using: context)
  }
}

// MARK: - Set Result

extension SharedQuery {
  /// Directly sets the result of a query.
  ///
  /// - Parameters:
  ///   - result: The `Result`.
  ///   - context: The `QueryContext` to set the result in.
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
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value.
  ///   - query: The `QueryRequest`.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
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

  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - query: The `QueryRequest`.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
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
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value.
  ///   - query: The `InfiniteQueryRequest`.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
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

  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - query: The `InfiniteQueryRequest`.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
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
  /// Refetches all existing pages on the query.
  ///
  /// This method will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  ///   - handler: An `InfiniteQueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func refetchAllPages(
    using context: QueryContext? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
    try await self.value.store.refetchAllPages(using: context, handler: handler)
  }

  /// Creates a `QueryTask` that refetches all existing pages on the query.
  ///
  /// The task will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  /// - Returns: A task to refetch all pages.
  public func refetchAllPagesTask(
    using context: QueryContext? = nil
  ) -> QueryTask<InfiniteQueryPages<State.PageID, State.PageValue>> {
    self.value.store.refetchAllPagesTask(using: context)
  }

  /// Fetches the page that will be placed after the last page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  ///   - handler: An `InfiniteQueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchNextPage(
    using context: QueryContext? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    try await self.value.store.fetchNextPage(using: context, handler: handler)
  }

  /// Creates a `QueryTask` to fetch the page that will be placed after the last page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  /// - Returns: The fetched page.
  public func fetchNextPageTask(
    using context: QueryContext? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    self.value.store.fetchNextPageTask(using: context)
  }

  /// Fetches the page that will be placed before the first page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  ///   - handler: An `InfiniteQueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchPreviousPage(
    using context: QueryContext? = nil,
    handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> = InfiniteQueryEventHandler()
  ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
    try await self.value.store.fetchPreviousPage(using: context, handler: handler)
  }

  /// Creates a `QueryTask` to fetch the page that will be placed before the first page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` to use for the underlying `QueryTask`.
  /// - Returns: The fetched page.
  public func fetchPreviousPageTask(
    using context: QueryContext? = nil
  ) -> QueryTask<InfiniteQueryPage<State.PageID, State.PageValue>?> {
    self.value.store.fetchPreviousPageTask(using: context)
  }
}

// MARK: - Mutations

extension SharedQuery {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value.
  ///   - mutation: The `MutationRequest`.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
  public init<
    Arguments: Sendable,
    Value: Sendable,
    Mutation: MutationRequest<Arguments, Value>
  >(
    wrappedValue: Value?,
    _ mutation: Mutation,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == MutationState<Arguments, Value> {
    self.init(
      mutation,
      initialState: MutationState(initialValue: wrappedValue),
      client: client,
      scheduler: scheduler
    )
  }

  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - mutation: The `MutationRequest`.
  ///   - client: A `QueryClient` to obtain the `QueryStore` from.
  ///   - scheduler: The ``SharedQueryStateScheduler`` to schedule state updates on.
  public init<
    Arguments: Sendable,
    Value: Sendable,
    Mutation: MutationRequest<Arguments, Value>
  >(
    _ mutation: Mutation,
    client: QueryClient? = nil,
    scheduler: some SharedQueryStateScheduler = .synchronous
  ) where State == MutationState<Arguments, Value> {
    self.init(mutation, initialState: MutationState(), client: client, scheduler: scheduler)
  }
}

extension SharedQuery where State: _MutationStateProtocol {
  /// Performs a mutation with a set of arguments.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to use.
  ///   - context: The `QueryContext` used by the underlying `QueryTask`.
  ///   - handler: A `MutationEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using context: QueryContext? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.value.store.mutate(with: arguments, using: context, handler: handler)
  }

  /// Creates a `QueryTask` that performs a mutation with a set of arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to use.
  ///   - context: The `QueryContext` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    with arguments: State.Arguments,
    using context: QueryContext? = nil
  ) -> QueryTask<State.Value> {
    self.value.store.mutateTask(with: arguments, using: context)
  }

  /// Retries the mutation with the most recently used set of arguments.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` used by the underlying `QueryTask`.
  ///   - handler: A `MutationEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func retryLatest(
    using context: QueryContext? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.value.store.retryLatest(using: context, handler: handler)
  }

  /// Creates a `QueryTask` that retries the mutation with the most recently used set of
  /// arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` for the task.
  /// - Returns: A task to retry the most recently used arguments on the mutation.
  public func retryLatestTask(using context: QueryContext? = nil) -> QueryTask<State.Value> {
    self.value.store.retryLatestTask(using: context)
  }
}

extension SharedQuery where State: _MutationStateProtocol, State.Arguments == Void {
  /// Performs a mutation with no arguments.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` used by the underlying `QueryTask`.
  ///   - handler: A `MutationEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    using context: QueryContext? = nil,
    handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
  ) async throws -> State.Value {
    try await self.mutate(with: (), using: context, handler: handler)
  }

  /// Creates a `QueryTask` that performs a mutation with no arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `QueryTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `QueryContext` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(using context: QueryContext? = nil) -> QueryTask<State.Value> {
    self.mutateTask(with: (), using: context)
  }
}
