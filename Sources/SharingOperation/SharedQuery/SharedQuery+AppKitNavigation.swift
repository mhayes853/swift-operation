#if SwiftOperationAppKitNavigation && canImport(AppKit)
  import AppKitNavigation
  import Dependencies

  // MARK: - Store Initializer

  extension SharedQuery {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - store: The `QueryStore` to subscribe to.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init(store: QueryStore<State>, animation: AppKitAnimation) {
      self.init(store: store, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - Query State Initializer

  extension SharedQuery {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - initialState: The initial state.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: Query,
      initialState: Query.State,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == Query.State {
      self.init(
        query,
        initialState: initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }

  // MARK: - Query Initializers

  extension SharedQuery {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Value: Sendable, Query: QueryRequest<Value, QueryState<Value?, Value>>>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: Query,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == Query.State {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: DefaultQuery<Query>,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == DefaultQuery<Query>.State {
      self.init(query, client: client, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - InfiniteQuery Initializers

  extension SharedQuery {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `InfiniteQueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `InfiniteQueryRequest`.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(query, client: client, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - Mutation Initializer

  extension SharedQuery {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - mutation: The `MutationRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      wrappedValue: Value?,
      _ mutation: Mutation,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == MutationState<Arguments, Value> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - mutation: The `MutationRequest`.
    ///   - client: A `QueryClient` to obtain the `QueryStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      _ mutation: Mutation,
      client: QueryClient? = nil,
      animation: AppKitAnimation
    ) where State == MutationState<Arguments, Value> {
      self.init(
        mutation,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }
#endif
