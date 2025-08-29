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
    public init<Operation: OperationRequest & Sendable>(
      _ operation: Operation,
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
      wrappedValue: Query.Value? = nil,
      _ query: Query,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == QueryState<Query.Value> {
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
      _ query: Query.Default,
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

  // MARK: - InfiniteQuery Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `InfiniteQueryRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue> {
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
    ///   - query: The `InfiniteQueryRequest`.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - transaction: The `UITransaction` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: Query.Default,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == DefaultOperationState<InfiniteQueryState<Query.PageID, Query.PageValue>> {
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
      wrappedValue: Mutation.ReturnValue?,
      _ mutation: Mutation,
      client: OperationClient? = nil,
      transaction: UITransaction
    ) where State == MutationState<Mutation.Arguments, Mutation.ReturnValue> {
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
      _ mutation: Mutation.Default,
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
