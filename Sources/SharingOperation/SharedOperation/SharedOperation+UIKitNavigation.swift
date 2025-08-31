#if SwiftOperationUIKitNavigation && canImport(UIKitNavigation)
  import UIKitNavigation
  import Dependencies

  // MARK: - Store Initializer

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - store: The `OperationStore` to subscribe to.
    ///   - scheduler: The `UIKitAnimation` to use for state updates.
    public init(store: OperationStore<State>, animation: UIKitAnimation) {
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
      animation: UIKitAnimation
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
    ///   - animation: The `UIKitAnimation` to use for state updates.
    public init<Query: QueryRequest>(
      wrappedValue: Query.State.StateValue = nil,
      _ query: Query,
      client: OperationClient? = nil,
      animation: UIKitAnimation
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
    ///   - animation: The `UIKitAnimation` to use for state updates.
    public init<Query: QueryRequest>(
      _ query: Query.Default,
      client: OperationClient? = nil,
      animation: UIKitAnimation
    ) where State == DefaultOperation<Query>.State {
      self.init(
        query,
        initialState: query.initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }

  // MARK: - InfiniteQuery Initializers

  extension SharedOperation {
    /// Creates a shared query.
    ///
    /// - Parameters:
    ///   - query: The `MutationRequest`.
    ///   - wrappedValue: The initial value.
    ///   - client: A `OperationClient` to obtain the `OperationStore` from.
    ///   - animation: The `UIKitAnimation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      wrappedValue: Query.State.StateValue = [],
      _ query: Query,
      client: OperationClient? = nil,
      animation: UIKitAnimation
    ) where State == InfiniteQueryState<Query.PageID, Query.PageValue, Query.PageFailure> {
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
    ///   - animation: The `UIKitAnimation` to use for state updates.
    public init<Query: InfiniteQueryRequest>(
      _ query: Query.Default,
      client: OperationClient? = nil,
      animation: UIKitAnimation
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
    ///   - animation: The `UIKitAnimation` to use for state updates.
    public init<Mutation: MutationRequest>(
      wrappedValue: Mutation.State.StateValue = nil,
      _ mutation: Mutation,
      client: OperationClient? = nil,
      animation: UIKitAnimation
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
    ///   - animation: The `UIKitAnimation` to use for state updates.
    public init<Mutation: MutationRequest>(
      _ mutation: Mutation.Default,
      client: OperationClient? = nil,
      animation: UIKitAnimation
    ) where State == DefaultOperation<Mutation>.State {
      self.init(
        mutation,
        initialState: mutation.initialState,
        client: client,
        scheduler: .transaction(UITransaction(animation: animation))
      )
    }
  }
#endif
