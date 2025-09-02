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
    public init<Operation: StatefulOperationRequest>(
      _ operation: sending Operation,
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
      wrappedValue: Query.State.StateValue = nil,
      _ query: sending Query,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == QueryState<Query.Value, Query.Failure> {
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
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == DefaultStateOperation<Query>.State {
      self.init(
        query,
        initialState: query.initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }

  // MARK: - Paginated Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `PaginatedRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: PaginatedRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: sending Query,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == PaginatedState<Query.PageID, Query.PageValue, Query.PageFailure> {
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
    ///   - query: The `PaginatedRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `AppKitAnimation` to use for state updates.
    public init<Query: PaginatedRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    )
    where
      State == DefaultOperationState<
        PaginatedState<Query.PageID, Query.PageValue, Query.PageFailure>
      >
    {
      self.init(
        query,
        initialState: query.initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
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
    public init<Mutation: MutationRequest>(
      wrappedValue: Mutation.State.StateValue = nil,
      _ mutation: sending Mutation,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
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
    public init<Mutation: MutationRequest>(
      _ mutation: sending Mutation.Default,
      client: OperationClient? = nil,
      animation: AppKitAnimation
    ) where State == DefaultStateOperation<Mutation>.State {
      self.init(
        mutation,
        initialState: mutation.initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }
#endif
