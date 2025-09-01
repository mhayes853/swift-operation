#if SwiftOperationNavigation
  import SwiftNavigation
  import Dependencies

  // MARK: - Store Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - store: The `OperationStore` to subscribe to.
    ///   - scheduler: The `UITransaction` to use for state updates.
    public init(store: OperationStore<State>, transaction: UITransaction) {
      self.init(store: store, scheduler: .transaction(transaction))
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
    public init<Operation: OperationRequest>(
      _ operation: sending Operation,
      initialState: Operation.State,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == Operation.State {
      self.init(
        operation,
        initialState: initialState,
        client: client,
        scheduler: .transaction(transaction)
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
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Query: QueryRequest>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: sending Query,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == QueryState<Query.Value, Query.Failure> {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .transaction(transaction)
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `QueryRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == DefaultOperation<Query>.State {
      self.init(
        query,
        initialState: query.initialState,
        client: client,
        scheduler: .transaction(transaction)
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
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Query: PaginatedRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: sending Query,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == PaginatedState<Query.PageID, Query.PageValue, Query.PageFailure> {
      self.init(
        wrappedValue: wrappedValue,
        query,
        client: client,
        scheduler: .transaction(transaction)
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `PaginatedRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Query: PaginatedRequest>(
      _ query: sending Query.Default,
      client: OperationClient? = nil,
      transaction: UITransaction
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
        scheduler: .transaction(transaction)
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
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Mutation: MutationRequest>(
      wrappedValue: Mutation.State.StateValue = nil,
      _ mutation: sending Mutation,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == MutationState<Mutation.Arguments, Mutation.MutateValue, Mutation.Failure> {
      self.init(
        mutation,
        initialState: MutationState(initialValue: wrappedValue),
        client: client,
        scheduler: .transaction(transaction)
      )
    }

    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - mutation: The `MutationRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Mutation: MutationRequest>(
      _ mutation: sending Mutation.Default,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == DefaultOperation<Mutation>.State {
      self.init(
        mutation,
        initialState: mutation.initialState,
        client: client,
        scheduler: .transaction(transaction)
      )
    }
  }
#endif
