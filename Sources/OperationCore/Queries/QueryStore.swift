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
