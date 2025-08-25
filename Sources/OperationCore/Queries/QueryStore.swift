// MARK: - Initializers

extension OperationStore {
  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``QueryRequest``.
  ///   - initialState: The initial state.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Query: QueryRequest>(
    query: Query,
    initialState: Query.State,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Query.State> where State == Query.State {
    .detached(operation: query, initialState: initialState, initialContext: initialContext)
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The ``QueryRequest``.
  ///   - initialValue: The initial value.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Query: QueryRequest>(
    query: Query,
    initialValue: Query.State.StateValue,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<Query.State>
  where
    Query.State == QueryState<Query.Value?, Query.Value>,
    State == QueryState<Query.Value?, Query.Value>
  {
    .detached(
      operation: query,
      initialState: Query.State(initialValue: initialValue),
      initialContext: initialContext
    )
  }

  /// Creates a detached store.
  ///
  /// Detached stores are not connected to a ``OperationClient``. As such, accessing the
  /// ``OperationContext/OperationClient`` context property in your query will always yield a nil value.
  /// Only use a detached store if you want a separate instances of a query runtime for the same query.
  ///
  /// - Parameters:
  ///   - query: The default ``QueryRequest``.
  ///   - initialContext: The default ``OperationContext``.
  /// - Returns: A store.
  public static func detached<Query: QueryRequest>(
    query: DefaultQuery<Query>,
    initialContext: OperationContext = OperationContext()
  ) -> OperationStore<DefaultQuery<Query>.State>
  where
    DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value>,
    State == DefaultQuery<Query>.State
  {
    .detached(
      operation: query,
      initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue),
      initialContext: initialContext
    )
  }
}

// MARK: - Fetching

extension OperationStore {
  /// Fetches the query's data.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to use for the underlying ``OperationTask``.
  ///   - handler: A ``QueryEventHandler`` to subscribe to events from fetching the data. (This
  ///     does not add an active subscriber to the store.)
  /// - Returns: The fetched data.
  @discardableResult
  @_disfavoredOverload
  public func fetch(
    using context: OperationContext? = nil,
    handler: QueryEventHandler<State> = QueryEventHandler()
  ) async throws -> State.OperationValue {
    try await self.fetch(using: context, handler: self.operationEventHandler(for: handler))
  }
}

// MARK: - Subscribing

extension OperationStore {
  /// Subscribes to events from this store using a ``QueryEventHandler``.
  ///
  /// If the subscription is the first active subscription on this store, this method will begin
  /// fetching the query's data if both ``isStale`` and ``isAutomaticFetchingEnabled`` are true. If
  /// the subscriber count drops to 0 whilst performing this data fetch, then the fetch is
  /// cancelled and a `CancellationError` will be present on the ``state`` property.
  ///
  /// - Parameter handler: The event handler.
  /// - Returns: A ``OperationSubscription``.
  @_disfavoredOverload
  public func subscribe(with handler: QueryEventHandler<State>) -> OperationSubscription {
    self.subscribe(with: self.operationEventHandler(for: handler))
  }
}

// MARK: - Helper

extension OperationStore {
  private func operationEventHandler(
    for handler: QueryEventHandler<State>
  ) -> OperationEventHandler<State> {
    OperationEventHandler(
      onStateChanged: handler.onStateChanged,
      onFetchingStarted: handler.onFetchingStarted,
      onFetchingEnded: handler.onFetchingEnded,
      onResultReceived: handler.onResultReceived
    )
  }
}
