import Dependencies
import Operation
import Sharing

// MARK: - SharedOperation

/// A property wrapper for observing the state and interacting with a `QueryRequest`.
///
/// ```swift
/// import SharingOperation
///
/// // This will begin fetching the post.
/// @SharedOperation(Post.query(for: 1)) var post
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
/// `OperationStore` on the projected value of this property wrapper.
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
public struct SharedOperation<State: OperationState & Sendable>: Sendable {
  @Shared var value: OperationStateKeyValue<State>

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

  /// Creates a shared operation.
  ///
  /// - Parameters:
  ///   - operation: The `OperationRequest`.
  ///   - initialState: The initial state.
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Operation: StatefulOperationRequest>(
    _ operation: sending Operation,
    initialState: Operation.State,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) where State == Operation.State {
    @Dependency(\.defaultOperationClient) var OperationClient
    self.init(
      store: (client ?? OperationClient).store(for: operation, initialState: initialState),
      scheduler: scheduler
    )
  }

  /// Creates an unbacked shared query.
  ///
  /// - Parameter initialState: The initial state of the query.
  public init(initialState: State) {
    self._value = Shared(
      value: OperationStateKeyValue(
        store: .detached(operation: UnbackedOperation(), initialState: initialState)
      )
    )
    self.isBacked = false
  }
}

// MARK: - Unbacked Initializers

extension SharedOperation {
  /// Creates an unbacked shared query.
  ///
  /// - Parameter wrappedValue: The initial value of the query.
  public init<Value: Sendable, Failure: Error>(
    wrappedValue: Value? = nil
  ) where State == QueryState<Value, Failure> {
    self.init(initialState: QueryState(initialValue: wrappedValue))
  }

  /// Creates an unbacked shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value of the query.
  ///   - initialPageId: The initial page id of the query.
  public init<PageID, PageValue, PageFailure>(
    wrappedValue: State.StateValue,
    initialPageId: PageID
  ) where State == PaginatedState<PageID, PageValue, PageFailure> {
    self.init(
      initialState: PaginatedState(initialValue: wrappedValue, initialPageId: initialPageId)
    )
  }

  /// Creates an unbacked shared query.
  ///
  /// - Parameter wrappedValue: The initial value of the query.
  public init<Arguments, MutateValue, MutateFailure>(
    wrappedValue: State.StateValue
  ) where State == MutationState<Arguments, MutateValue, MutateFailure> {
    self.init(initialState: MutationState(initialValue: wrappedValue))
  }
}

// MARK: - Store Initializer

extension SharedOperation {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - store: The `OperationStore` to subscribe to.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init(
    store: OperationStore<State>,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) {
    self._value = Shared(
      wrappedValue: OperationStateKeyValue(store: store),
      OperationStateKey(store: store, scheduler: scheduler)
    )
  }
}

// MARK: - Shared Properties

extension SharedOperation {
  /// Loads the data from this query.
  public func load() async throws {
    try await self.run()
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

extension SharedOperation {
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

extension SharedOperation {
  /// Exclusively accesses the query properties inside the specified closure.
  ///
  /// The property-wrapper is thread-safe due to the thread-safety of the underlying `OperationStore`,
  /// but accessing individual properties without exclusive access can still lead to high-level
  /// data races. Use this method to ensure that your code has exclusive access to the store when
  /// performing multiple property accesses to compute a value or modify the underlying store.
  ///
  /// ```swift
  /// @SharedOperation<QueryState<Int, Int>> var value
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

extension SharedOperation {
  /// The backing `OperationStore` for this shared query.
  public var store: OperationStore<State> {
    self.value.store
  }
}

// MARK: - Dynamic Member Lookup

extension SharedOperation {
  public subscript<Value: Sendable>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.value.store.state[keyPath: keyPath]
  }

  public subscript<Value: Sendable>(
    dynamicMember keyPath: KeyPath<OperationStore<State>, Value>
  ) -> Value {
    self.value.store[keyPath: keyPath]
  }

  public subscript<Value: Sendable>(
    dynamicMember keyPath: ReferenceWritableKeyPath<OperationStore<State>, Value>
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

extension SharedOperation {
  /// Runs the operation.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  ///   - handler: A `OperationEventHandler` to subscribe to events from fetching the data.
  ///   (This does not add an active subscriber to the store.)
  /// - Returns: The data returned from the operation.
  @discardableResult
  public func run(
    using context: OperationContext? = nil,
    handler: OperationEventHandler<State> = OperationEventHandler()
  ) async throws(State.Failure) -> State.OperationValue {
    try await self.store.run(using: context, handler: handler)
  }

  /// Creates a `OperationTask` to run the operation.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameter context: The `OperationContext` for the task.
  /// - Returns: A task to run the operation.
  @discardableResult
  public func runTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.OperationValue, State.Failure> {
    self.value.store.runTask(using: context)
  }
}

// MARK: - Fetch

extension SharedOperation where State: _QueryStateProtocol {
  /// Fetches the query's data.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  ///   - handler: A `QueryEventHandler` to subscribe to events from fetching the data.
  ///   (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func fetch(
    using context: OperationContext? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws(State.Failure) -> State.OperationValue {
    try await self.value.store.fetch(using: context, handler: handler)
  }

  /// Creates a `OperationTask` to fetch the query's data.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameter context: The `OperationContext` for the task.
  /// - Returns: A task to fetch the query's data.
  public func fetchTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.OperationValue, State.Failure> {
    self.value.store.fetchTask(using: context)
  }
}

// MARK: - Reset

extension SharedOperation {
  /// Resets the state of the query to its original values.
  ///
  /// > Important: This will cancel all active `OperationTask`s on the query. Those cancellations will not be
  /// > reflected in the reset query state.
  ///
  /// - Parameter context: The `OperationContext` to reset the query in.
  public func resetState(using context: OperationContext? = nil) {
    self.value.store.resetState(using: context)
  }
}

// MARK: - Set Result

extension SharedOperation {
  /// Directly sets the result of a query.
  ///
  /// - Parameters:
  ///   - result: The `Result`.
  ///   - context: The `OperationContext` to set the result in.
  public func setResult(
    to result: Result<State.StateValue, State.Failure>,
    using context: OperationContext? = nil
  ) {
    self.value.store.setResult(to: result, using: context)
  }
}

// MARK: - Equatable

extension SharedOperation: Equatable where State.StateValue: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.value.currentValue == rhs.value.currentValue
  }
}

// MARK: - Queries

extension SharedOperation {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value.
  ///   - query: The `QueryRequest`.
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Query: QueryRequest>(
    wrappedValue: Query.State.StateValue = nil,
    _ query: sending Query,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) where State == QueryState<Query.Value, Query.Failure> {
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
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Query: QueryRequest>(
    _ query: sending Query.Default,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) where State == DefaultStateOperation<Query>.State {
    self.init(query, initialState: query.initialState, client: client, scheduler: scheduler)
  }
}

// MARK: - InfiniteQueries

extension SharedOperation {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value.
  ///   - query: The `PaginatedRequest`.
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Query: PaginatedRequest>(
    wrappedValue: Query.State.StateValue = [],
    _ query: sending Query,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) where State == PaginatedState<Query.PageID, Query.PageValue, Query.PageFailure> {
    self.init(
      query,
      initialState: PaginatedState(
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
  ///   - query: The `PaginatedRequest`.
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Query: PaginatedRequest>(
    _ query: sending Query.Default,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  )
  where
    State == DefaultOperationState<
      PaginatedState<Query.PageID, Query.PageValue, Query.PageFailure>
    >
  {
    self.init(query, initialState: query.initialState, client: client, scheduler: scheduler)
  }
}

extension SharedOperation where State: _PaginatedStateProtocol {
  /// Refetches all existing pages on the query.
  ///
  /// This method will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  ///   - handler: An `PaginatedEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  public func refetchAllPages(
    using context: OperationContext? = nil,
    handler: PaginatedEventHandler<State> = PaginatedEventHandler()
  ) async throws(State.Failure) -> Pages<State.PageID, State.PageValue> {
    try await self.value.store.refetchAllPages(using: context, handler: handler)
  }

  /// Creates a `OperationTask` that refetches all existing pages on the query.
  ///
  /// The task will refetch pages in a waterfall effect, starting from the first page, and then
  /// continuing until either the last page is fetched, or until no more pages can be fetched.
  ///
  /// If no pages have been fetched previously, then no pages will be fetched.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  /// - Returns: A task to refetch all pages.
  public func refetchAllPagesTask(
    using context: OperationContext? = nil
  ) -> OperationTask<Pages<State.PageID, State.PageValue>, State.Failure> {
    self.value.store.refetchAllPagesTask(using: context)
  }

  /// Fetches the page that will be placed after the last page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  ///   - handler: An `PaginatedEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchNextPage(
    using context: OperationContext? = nil,
    handler: PaginatedEventHandler<State> = PaginatedEventHandler()
  ) async throws(State.Failure) -> Page<State.PageID, State.PageValue>? {
    try await self.value.store.fetchNextPage(using: context, handler: handler)
  }

  /// Creates a `OperationTask` to fetch the page that will be placed after the last page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  /// - Returns: The fetched page.
  public func fetchNextPageTask(
    using context: OperationContext? = nil
  ) -> OperationTask<Page<State.PageID, State.PageValue>?, State.Failure> {
    self.value.store.fetchNextPageTask(using: context)
  }

  /// Fetches the page that will be placed before the first page in ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// This method can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  ///   - handler: An `PaginatedEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The fetched page.
  @discardableResult
  public func fetchPreviousPage(
    using context: OperationContext? = nil,
    handler: PaginatedEventHandler<State> = PaginatedEventHandler()
  ) async throws(State.Failure) -> Page<State.PageID, State.PageValue>? {
    try await self.value.store.fetchPreviousPage(using: context, handler: handler)
  }

  /// Creates a `OperationTask` to fetch the page that will be placed before the first page in
  /// ``currentValue``.
  ///
  /// If no pages have been previously fetched, the initial page is fetched.
  ///
  /// The task can fetch data in parallel with ``fetchNextPage(using:handler:)``.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
  /// - Returns: The fetched page.
  public func fetchPreviousPageTask(
    using context: OperationContext? = nil
  ) -> OperationTask<Page<State.PageID, State.PageValue>?, State.Failure> {
    self.value.store.fetchPreviousPageTask(using: context)
  }
}

// MARK: - Mutations

extension SharedOperation {
  /// Creates a shared query.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value.
  ///   - mutation: The `MutationRequest`.
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Mutation: MutationRequest>(
    wrappedValue: Mutation.State.StateValue = nil,
    _ mutation: sending Mutation,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
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
  ///   - client: A `OperationClient` to obtain the `OperationStore` from.
  ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
  public init<Mutation: MutationRequest>(
    _ mutation: sending Mutation.Default,
    client: OperationClient? = nil,
    scheduler: some SharedOperationStateScheduler = .synchronous
  ) where State == DefaultStateOperation<Mutation>.State {
    self.init(mutation, initialState: mutation.initialState, client: client, scheduler: scheduler)
  }
}

extension SharedOperation where State: _MutationStateProtocol {
  /// Performs a mutation with a set of arguments.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to use.
  ///   - context: The `OperationContext` used by the underlying `OperationTask`.
  ///   - handler: A `MutationEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    with arguments: State.Arguments,
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.value.store.mutate(with: arguments, using: context, handler: handler)
  }

  /// Creates a `OperationTask` that performs a mutation with a set of arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - arguments: The set of arguments to use.
  ///   - context: The `OperationContext` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    with arguments: State.Arguments,
    using context: OperationContext? = nil
  ) -> OperationTask<State.Value, State.Failure> {
    self.value.store.mutateTask(with: arguments, using: context)
  }

  /// Retries the mutation with the most recently used set of arguments.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` used by the underlying `OperationTask`.
  ///   - handler: A `MutationEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func retryLatest(
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.value.store.retryLatest(using: context, handler: handler)
  }

  /// Creates a `OperationTask` that retries the mutation with the most recently used set of
  /// arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// > Important: Calling this method without previously having called ``mutate(using:handler:)``
  /// > will result in a purple runtime warning in Xcode, and a test failure for current running
  /// > test. Additionally, the mutation will also throw an error.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` for the task.
  /// - Returns: A task to retry the most recently used arguments on the mutation.
  public func retryLatestTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.Value, State.Failure> {
    self.value.store.retryLatestTask(using: context)
  }
}

extension SharedOperation where State: _MutationStateProtocol, State.Arguments == Void {
  /// Performs a mutation with no arguments.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` used by the underlying `OperationTask`.
  ///   - handler: A `MutationEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
  /// - Returns: The mutated value.
  @discardableResult
  public func mutate(
    using context: OperationContext? = nil,
    handler: MutationEventHandler<State> = MutationEventHandler()
  ) async throws(State.Failure) -> State.Value {
    try await self.mutate(with: (), using: context, handler: handler)
  }

  /// Creates a `OperationTask` that performs a mutation with no arguments.
  ///
  /// The returned task does not begin fetching immediately. Rather you must call
  /// `OperationTask.runIfNeeded` to fetch the data.
  ///
  /// - Parameters:
  ///   - context: The `OperationContext` for the task.
  /// - Returns: A task to perform the mutation.
  public func mutateTask(
    using context: OperationContext? = nil
  ) -> OperationTask<State.Value, State.Failure> {
    self.mutateTask(with: (), using: context)
  }
}
