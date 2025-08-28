#if SwiftOperationAppKitNavigation && canImport(AppKit)
  import AppKitNavigation
  import Dependencies

  // MARK: - Store Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - store: The `OperationStore` to subscribe to.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init(store: OperationStore<State>, animation: AppKitAnimation) {
      self.init(store: store, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - Operation State Initializer

  extension SharedOperation {
    /// Creates a shared operation.
    ///
    /// - Parameters:
    ///   - operation: The `OperationRequest`.
    ///   - initialState: The initial state.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - scheduler: The ``SharedOperationStateScheduler`` to schedule state updates on.
    public init<Operation: OperationRequest & Sendable>(
      _ operation: Operation,
      initialState: Operation.State,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == Operation.State {
      self.init(
        operation,
        initialState: initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }

  // MARK: - Query Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: QueryRequest>(
      wrappedValue: Query.Value? = nil,
      _ query: Query,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == QueryState<Query.Value>, Query.State == QueryState<Query.Value> {
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
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: Query.Default,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == DefaultQueryState<Query.Value> {
      self.init(query, client: client, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - InfiniteQuery Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `InfiniteQueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: OperationClient? = nil,
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
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: DefaultInfiniteQuery<Query>,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
      self.init(query, client: client, scheduler: .transaction(UITransaction(animation: animation)))
    }
  }

  // MARK: - Mutation Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - mutation: The `MutationRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      wrappedValue: Value?,
      _ mutation: Mutation,
      client: OperationClient? = nil,
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
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<
      Arguments: Sendable,
      Value: Sendable,
      Mutation: MutationRequest<Arguments, Value>
    >(
      _ mutation: Mutation,
      client: OperationClient? = nil,
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
