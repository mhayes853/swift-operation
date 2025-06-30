#if canImport(SwiftUI)
  import SwiftUI
  import IdentifiedCollections

  extension State {
    /// A property wrapper for observing a query in a SwiftUI view.
    ///
    /// ```swift
    /// import QuerySwiftUI
    ///
    /// struct PostView: View {
    ///   @State.Query<Post.Query> var state: Post.Query.State
    ///
    ///   init(id: Int) {
    ///     self._state = State.Query(Post.query(for: id))
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
    /// `QueryStore` on the projected value of this property wrapper.
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
    ///   @State.Query<Post.Query> var state: Post.Query.State
    ///
    ///   init(id: Int) {
    ///     self._state = State.Query(Post.query(for: id))
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

      /// Creates a state property for the specified `QueryStore`.
      ///
      /// - Parameters:
      ///   - store: The store to observe.
      ///   - transaction: The transaction to apply to state updates.
      public init(store: QueryStore<State>, transaction: Transaction? = nil) {
        self._store = { _ in store }
        self._state = SwiftUI.State(initialValue: store.state)
        self.transaction = MainActorTransaction(transaction: transaction)
      }

      /// Creates a state property for the specified `QueryRequest`.
      ///
      /// - Parameters:
      ///   - query: The query to observe.
      ///   - initialState: The initially supplied state.
      ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
      ///   - transaction: The transaction to apply to state updates.
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
    /// Creates a state property for the specified `QueryStore`.
    ///
    /// - Parameters:
    ///   - store: The store to observe.
    ///   - animation: The animation to apply to state updates.
    public init(store: QueryStore<State>, animation: Animation) {
      self.init(store: store, transaction: Transaction(animation: animation))
    }
  }

  // MARK: - Query Init

  extension State.Query {
    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - transaction: The transaction to apply to state updates.
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

    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - animation: The animation to apply to state updates.
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

    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - transaction: The transaction to apply to state updates.
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

    /// Creates a state property for the specified `QueryRequest`.
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - animation: The animation to apply to state updates.
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
    /// The underlying `QueryStore` associated with this state property.
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
    ///  // ✅ No data races.
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
    /// Directly sets the result of a query.
    ///
    /// - Parameters:
    ///   - result: The `Result`.
    ///   - context: The `QueryContext` to set the result in.
    public func setResult(
      to result: Result<Value, any Error>,
      using context: QueryContext? = nil
    ) {
      self.store.setResult(to: result, using: context)
    }

    /// Resets the state of the query to its original values.
    ///
    /// > Important: This will cancel all active `QueryTask`s on the query. Those cancellations will not be
    /// > reflected in the reset query state.
    ///
    /// - Parameter context: The `QueryContext` to reset the query in.
    public func resetState(using context: QueryContext? = nil) {
      self.store.resetState(using: context)
    }
  }

  // MARK: - Fetch

  extension State.Query {
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
      try await self.store.fetch(using: context, handler: handler)
    }

    /// Creates a `QueryTask` to fetch the query's data.
    ///
    /// The returned task does not begin fetching immediately. Rather you must call
    /// `QueryTask.runIfNeeded` to fetch the data.
    ///
    /// - Parameter context: The `QueryContext` for the task.
    /// - Returns: A task to fetch the query's data.
    public func fetchTask(using context: QueryContext? = nil) -> QueryTask<State.QueryValue> {
      self.store.fetchTask(using: context)
    }
  }

  // MARK: - Infinite Queries

  extension State.Query {
    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - transaction: The transaction to apply to state updates.
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

    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - animation: The animation to apply to state updates.
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

    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - transaction: The transaction to apply to state updates.
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

    /// Creates a state property for an `InfiniteQueryRequest`
    ///
    /// - Parameters:
    ///   - query: The query to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - animation: The animation to apply to state updates.
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
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPages<State.PageID, State.PageValue> {
      try await self.store.refetchAllPages(using: context, handler: handler)
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
      self.store.refetchAllPagesTask(using: context)
    }

    /// Fetches the page that will be placed after the last page in ``wrappedValue``.
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
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchNextPage(using: context, handler: handler)
    }

    /// Creates a `QueryTask` to fetch the page that will be placed after the last page in
    /// ``wrappedValue``.
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
      self.store.fetchNextPageTask(using: context)
    }

    /// Fetches the page that will be placed before the first page in ``wrappedValue``.
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
      handler: InfiniteQueryEventHandler<State.PageID, State.PageValue> =
        InfiniteQueryEventHandler()
    ) async throws -> InfiniteQueryPage<State.PageID, State.PageValue>? {
      try await self.store.fetchPreviousPage(using: context, handler: handler)
    }

    /// Creates a `QueryTask` to fetch the page that will be placed before the first page in
    /// ``wrappedValue``.
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
      self.store.fetchPreviousPageTask(using: context)
    }
  }

  // MARK: - Mutations

  extension State.Query {
    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - transaction: The transaction to apply to state updates.
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

    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - animation: The animation to apply to state updates.
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

    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - transaction: The transaction to apply to state updates.
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

    /// Creates a state property for the specified `MutationRequest`.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to observe.
    ///   - client: An optional `QueryClient` to override ``SwiftUICore/EnvironmentValues/queryClient``.
    ///   - animation: The animation to apply to state updates.
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
    /// Performs a mutation.
    ///
    /// - Parameters:
    ///   - arguments: The set of arguments to mutate with.
    ///   - context: The `QueryContext` used by the underlying `QueryTask`.
    ///   - handler: A `QueryEventHandler` to subscribe to events from fetching the data. (This does not add an active subscriber to the store.)
    /// - Returns: The mutated value.
    @discardableResult
    public func mutate(
      with arguments: State.Arguments,
      using context: QueryContext? = nil,
      handler: MutationEventHandler<State.Arguments, State.Value> = MutationEventHandler()
    ) async throws -> State.Value {
      try await self.store.mutate(with: arguments, using: context, handler: handler)
    }

    /// Creates a `QueryTask` that performs a mutation.
    ///
    /// The returned task does not begin fetching immediately. Rather you must call
    /// `QueryTask.runIfNeeded` to fetch the data.
    ///
    /// - Parameters:
    ///   - arguments: The set of arguments to mutate with.
    ///   - context: The `QueryContext` for the task.
    /// - Returns: A task to perform the mutation.
    public func mutateTask(
      with arguments: State.Arguments,
      using context: QueryContext? = nil
    ) -> QueryTask<State.Value> {
      self.store.mutateTask(with: arguments, using: context)
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
      try await self.store.retryLatest(using: context, handler: handler)
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
      self.store.retryLatestTask(using: context)
    }
  }

  extension State.Query where State: _MutationStateProtocol, State.Arguments == Void {
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
      try await self.store.mutate(using: context, handler: handler)
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
      self.store.mutateTask(using: context)
    }
  }
#endif
