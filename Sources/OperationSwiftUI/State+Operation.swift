#if canImport(SwiftUI)
  import SwiftUI
  import IdentifiedCollections

  extension State {
    /// A property wrapper for observing a query in a SwiftUI view.
    ///
    /// ```swift
    /// import OperationSwiftUI
    ///
    /// struct PostView: View {
    ///   @State.Operation<Post.Query> var state: Post.Query.State
    ///
    ///   init(id: Int) {
    ///     self._state = State.Operation(Post.query(for: id))
    ///   }
    ///
    ///   var body: some View {
    ///     VStack {
    ///       switch state.status {
    ///       case .idle:
    ///         Text("Idle")
    ///       case .loading:
    ///         ProgressView()
    ///       case let .result(.success(post)):
    ///         Text(post.title)
    ///         Text(post.body)
    ///       case let .result(.failure(error)):
    ///         Text(error.localizedDescription)
    ///       }
    ///     }
    ///   }
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
    /// If you want to derive a binding to the state value, use ``SwiftUICore/Binding/init(_:)``.
    ///
    /// ```swift
    /// struct PostTitleFormView: View {
    ///   @State.Operation<Post.Query> var state: Post.Query.State
    ///
    ///   init(id: Int) {
    ///     self._state = State.Operation(Post.query(for: id))
    ///   }
    ///
    ///   var body: some View {
    ///     PostTitleTextField(text: Binding(self.$post).title)
    ///   }
    /// }
    /// ```
    @MainActor
    @propertyWrapper
    @dynamicMemberLookup
    public struct Operation<State: OperationState> where Value == State.StateValue {
      @SwiftUI.State var state: State

      @Environment(\.operationClient) private var operationClient

      private let _store: (OperationClient) -> OperationStore<State>
      private let transaction: MainActorTransaction
      private var subscription = OperationSubscription.empty
      private var previousStore: OperationStore<State>?

      public var wrappedValue: Value {
        get { self.state.currentValue }
        nonmutating set { self.store.currentValue = newValue }
      }

      public var projectedValue: Self {
        get { self }
        set { self = newValue }
      }

      /// Creates a state property for the specified `OperationStore`.
      ///
      /// - Parameters:
      ///   - store: The store to observe.
      ///   - transaction: The transaction to apply to state updates.
      public init(store: OperationStore<State>, transaction: Transaction? = nil) {
        self._store = { _ in store }
        self._state = SwiftUI.State(initialValue: store.state)
        self.transaction = MainActorTransaction(transaction: transaction)
      }

      /// Creates a state property for the specified `OperationRequest`.
      ///
      /// - Parameters:
      ///   - operation: The operation to observe.
      ///   - initialState: The initially supplied state.
      ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
      ///   - transaction: The transaction to apply to state updates.
      public init<Operation: OperationRequest>(
        _ operation: sending @escaping @autoclosure () -> Operation,
        initialState: Operation.State,
        client: OperationClient? = nil,
        transaction: Transaction? = nil
      ) where State == Operation.State {
        self._store = { (client ?? $0).store(for: operation(), initialState: initialState) }
        self._state = SwiftUI.State(initialValue: initialState)
        self.transaction = MainActorTransaction(transaction: transaction)
      }
    }
  }

  // MARK: - Store Inits

  extension State.Operation {
    /// Creates a state property for the specified `OperationStore`.
    ///
    /// - Parameters:
    ///   - store: The store to observe.
    ///   - animation: The animation to apply to state updates.
    public init(store: OperationStore<State>, animation: Animation) {
      self.init(store: store, transaction: Transaction(animation: animation))
    }
  }

  // MARK: - Query Init

  extension State.Operation {
    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - transaction: The transaction to apply to state updates.
    public init<Query: QueryRequest>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: sending Query,
      client: OperationClient? = nil,
      transaction: Transaction? = nil
    ) where State == QueryState<Query.Value, Query.Failure> {
      self.init(
        query,
        initialState: QueryState(initialValue: wrappedValue),
        client: client,
        transaction: transaction
      )
    }

    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - animation: The animation to apply to state updates.
    public init<Query: QueryRequest>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: sending Query,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == QueryState<Query.Value, Query.Failure> {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        transaction: Transaction(animation: animation)
      )
    }

    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - transaction: The transaction to apply to state updates.
    public init<Query: QueryRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      transaction: Transaction? = nil
    ) where State == DefaultOperation<Query>.State {
      self.init(query, initialState: query.initialState, client: client, transaction: transaction)
    }

    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - animation: The animation to apply to state updates.
    public init<Query: QueryRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == DefaultOperation<Query>.State {
      self.init(
        query,
        initialState: query.initialState,
        client: client,
        transaction: Transaction(animation: animation)
      )
    }
  }

  // MARK: - Store

  extension State.Operation {
    /// The underlying `OperationStore` associated with this state property.
    public var store: OperationStore<State> {
      self._store(self.operationClient)
    }
  }

  // MARK: - Exclusive Access

  extension State.Operation {
    /// Exclusively accesses the query properties inside the specified closure.
    ///
    /// The property-wrapper is thread-safe due to the thread-safety of the underlying `OperationStore`,
    /// but accessing individual properties without exclusive access can still lead to high-level
    /// data races. Use this method to ensure that your code has exclusive access to the store when
    /// performing multiple property accesses to compute a value or modify the underlying store.
    ///
    /// ```swift
    /// @State.Operation<QueryState<Int, Int>> var value
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
    public func withExclusiveAccess<T>(_ fn: (Self) throws -> sending T) rethrows -> sending T {
      try self.store.withExclusiveAccess { _ in try fn(self) }
    }
  }

  // MARK: - DynamicProperty

  extension State.Operation: @preconcurrency DynamicProperty {
    public mutating func update() {
      defer { self.previousStore = self.store }
      guard self.subscription == .empty || self.previousStore !== self.store else { return }
      self.subscription.cancel()
      let stateValue = self._state
      let transaction = self.transaction
      self.subscription = self.store.subscribe(
        with: OperationEventHandler { state, _ in
          Task { @MainActor in
            withTransaction(transaction) { stateValue.wrappedValue = state }
          }
        }
      )
    }
  }

  // MARK: - Dynamic Member Lookup

  extension State.Operation {
    public subscript<V>(dynamicMember keyPath: KeyPath<State, V>) -> V {
      self.state[keyPath: keyPath]
    }

    public subscript<V>(dynamicMember keyPath: KeyPath<OperationStore<State>, V>) -> V {
      self.store[keyPath: keyPath]
    }

    public subscript<V>(
      dynamicMember keyPath: ReferenceWritableKeyPath<OperationStore<State>, V>
    ) -> V {
      get { self.store[keyPath: keyPath] }
      set { self.store[keyPath: keyPath] = newValue }
    }
  }

  // MARK: - State Functions

  extension State.Operation {
    /// Directly sets the result of a query.
    ///
    /// - Parameters:
    ///   - result: The `Result`.
    ///   - context: The `OperationContext` to set the result in.
    public func setResult(
      to result: Result<Value, State.Failure>,
      using context: OperationContext? = nil
    ) {
      self.store.setResult(to: result, using: context)
    }

    /// Resets the state of the query to its original values.
    ///
    /// > Important: This will cancel all active `OperationTask`s on the query. Those cancellations will not be
    /// > reflected in the reset query state.
    ///
    /// - Parameter context: The `OperationContext` to reset the query in.
    public func resetState(using context: OperationContext? = nil) {
      self.store.resetState(using: context)
    }
  }

  // MARK: - Fetch

  extension State.Operation {
    /// Fetches the operation's data.
    ///
    /// - Parameters:
    ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
    ///   - handler: A `OperationEventHandler` to subscribe to events from fetching the data.
    ///   (This does not add an active subscriber to the store.)
    /// - Returns: The fetched data.
    @discardableResult
    public func run(
      using context: OperationContext? = nil,
      handler: OperationEventHandler<State> = OperationEventHandler()
    ) async throws(State.Failure) -> State.OperationValue {
      try await self.store.run(using: context, handler: handler)
    }

    /// Creates a `OperationTask` to fetch the query's data.
    ///
    /// The returned task does not begin fetching immediately. Rather you must call
    /// `OperationTask.runIfNeeded` to fetch the data.
    ///
    /// - Parameter context: The `OperationContext` for the task.
    /// - Returns: A task to fetch the query's data.
    public func runTask(
      using context: OperationContext? = nil
    ) -> OperationTask<State.OperationValue, State.Failure> {
      self.store.runTask(using: context)
    }
  }

  // MARK: - Fetch

  extension State.Operation where State: _QueryStateProtocol {
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
      try await self.store.fetch(using: context, handler: handler)
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
      self.store.fetchTask(using: context)
    }
  }

  // MARK: - Infinite Queries

  extension State.Operation {
    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - transaction: The transaction to apply to state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: sending Query,
      client: OperationClient? = nil,
      transaction: Transaction?
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue, Query.PageFailure> {
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

    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - animation: The animation to apply to state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: sending Query,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue, Query.PageFailure> {
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

    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - transaction: The transaction to apply to state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      transaction: Transaction? = nil
    )
    where
      State == DefaultOperationState<
        InfiniteQueryState<Query.PageID, Query.PageValue, Query.PageFailure>
      >
    {
      self.init(query, initialState: query.initialState, client: client, transaction: transaction)
    }

    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - animation: The animation to apply to state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      animation: Animation
    )
    where
      State == DefaultOperationState<
        InfiniteQueryState<Query.PageID, Query.PageValue, Query.PageFailure>
      >
    {
      self.init(
        query,
        initialState: query.initialState,
        client: client,
        transaction: Transaction(animation: animation)
      )
    }
  }

  extension State.Operation where State: _InfiniteQueryStateProtocol {
    /// Refetches all existing pages on the query.
    ///
    /// This method will refetch pages in a waterfall effect, starting from the first page, and then
    /// continuing until either the last page is fetched, or until no more pages can be fetched.
    ///
    /// If no pages have been fetched previously, then no pages will be fetched.
    ///
    /// - Parameters:
    ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
    ///   - handler: An `InfiniteQueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
    /// - Returns: The fetched data.
    @discardableResult
    public func refetchAllPages(
      using context: OperationContext? = nil,
      handler: InfiniteQueryEventHandler<State> = InfiniteQueryEventHandler()
    ) async throws(State.Failure) -> InfiniteQueryPages<State.PageID, State.PageValue> {
      try await self.store.refetchAllPages(using: context, handler: handler)
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
    ) -> OperationTask<InfiniteQueryPages<State.PageID, State.PageValue>, State.Failure> {
      self.store.refetchAllPagesTask(using: context)
    }

    /// Fetches the page that will be placed after the last page in ``wrappedValue``.
    ///
    /// If no pages have been previously fetched, the initial page is fetched.
    ///
    /// This method can fetch data in parallel with ``fetchPreviousPage(using:handler:)``.
    ///
    /// - Parameters:
    ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
    ///   - handler: An `InfiniteQueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
    /// - Returns: The fetched page.
    @discardableResult
    public func fetchNextPage(
      using context: OperationContext? = nil,
      handler: InfiniteQueryEventHandler<State> = InfiniteQueryEventHandler()
    ) async throws(State.Failure) -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchNextPage(using: context, handler: handler)
    }

    /// Creates a `OperationTask` to fetch the page that will be placed after the last page in
    /// ``wrappedValue``.
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
    ) -> OperationTask<InfiniteQueryPage<State.PageID, State.PageValue>?, State.Failure> {
      self.store.fetchNextPageTask(using: context)
    }

    /// Fetches the page that will be placed before the first page in ``wrappedValue``.
    ///
    /// If no pages have been previously fetched, the initial page is fetched.
    ///
    /// This method can fetch data in parallel with ``fetchNextPage(using:handler:)``.
    ///
    /// - Parameters:
    ///   - context: The `OperationContext` to use for the underlying `OperationTask`.
    ///   - handler: An `InfiniteQueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
    /// - Returns: The fetched page.
    @discardableResult
    public func fetchPreviousPage(
      using context: OperationContext? = nil,
      handler: InfiniteQueryEventHandler<State> = InfiniteQueryEventHandler()
    ) async throws(State.Failure) -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchPreviousPage(using: context, handler: handler)
    }

    /// Creates a `OperationTask` to fetch the page that will be placed before the first page in
    /// ``wrappedValue``.
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
    ) -> OperationTask<InfiniteQueryPage<State.PageID, State.PageValue>?, State.Failure> {
      self.store.fetchPreviousPageTask(using: context)
    }
  }

  // MARK: - Mutations

  extension State.Operation {
    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - transaction: The transaction to apply to state updates.
    public init<Mutation: MutationRequest>(
      wrappedValue: Mutation.State.StateValue = nil,
      _ mutation: sending Mutation,
      client: OperationClient? = nil,
      transaction: Transaction? = nil
    ) where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        transaction: transaction
      )
    }

    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - animation: The animation to apply to state updates.
    public init<Mutation: MutationRequest>(
      wrappedValue: Mutation.State.StateValue = nil,
      _ mutation: sending Mutation,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        transaction: Transaction(animation: animation)
      )
    }

    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - transaction: The transaction to apply to state updates.
    public init<Mutation: MutationRequest>(
      _ mutation: sending Mutation.Default,
      client: OperationClient? = nil,
      transaction: Transaction? = nil
    ) where State == DefaultOperation<Mutation>.State {
      self.init(
        mutation,
        initialState: mutation.initialState,
        client: client,
        transaction: transaction
      )
    }

    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `OperationClient` to override ``SwiftUICore/EnvironmentValues/OperationClient``.
    ///   - animation: The animation to apply to state updates.
    public init<Mutation: MutationRequest>(
      _ mutation: Mutation.Default,
      client: OperationClient? = nil,
      animation: Animation
    ) where State == DefaultOperation<Mutation>.State {
      self.init(
        mutation,
        initialState: mutation.initialState,
        client: client,
        transaction: Transaction(animation: animation)
      )
    }
  }

  extension State.Operation where State: _MutationStateProtocol {
    /// Performs a mutation.
    ///
    /// - Parameters:
    ///   - arguments: The set of arguments to mutate with.
    ///   - context: The `OperationContext` used by the underlying `OperationTask`.
    ///   - handler: A `QueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
    /// - Returns: The mutated value.
    @discardableResult
    public func mutate(
      with arguments: State.Arguments,
      using context: OperationContext? = nil,
      handler: MutationEventHandler<State> = MutationEventHandler()
    ) async throws(State.Failure) -> State.Value {
      try await self.store.mutate(with: arguments, using: context, handler: handler)
    }

    /// Creates a `OperationTask` that performs a mutation.
    ///
    /// The returned task does not begin fetching immediately. Rather you must call
    /// `OperationTask.runIfNeeded` to fetch the data.
    ///
    /// - Parameters:
    ///   - arguments: The set of arguments to mutate with.
    ///   - context: The `OperationContext` for the task.
    /// - Returns: A task to perform the mutation.
    public func mutateTask(
      with arguments: State.Arguments,
      using context: OperationContext? = nil
    ) -> OperationTask<State.Value, State.Failure> {
      self.store.mutateTask(with: arguments, using: context)
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
      try await self.store.retryLatest(using: context, handler: handler)
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
      self.store.retryLatestTask(using: context)
    }
  }

  extension State.Operation where State: _MutationStateProtocol, State.Arguments == Void {
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
      try await self.store.mutate(using: context, handler: handler)
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
      self.store.mutateTask(using: context)
    }
  }
#endif
