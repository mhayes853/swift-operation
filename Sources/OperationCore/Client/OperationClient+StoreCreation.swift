// MARK: - StoreCreator

extension OperationClient {
  /// A protocol that controls how a ``OperationClient`` creates ``OperationStore`` instances.
  ///
  /// Conform to this protocol when you want to apply custom modifiers by default to all of your
  /// operations.
  /// ```swift
  /// struct MyStoreCreator: OperationClient.StoreCreator {
  ///    func store<Operation: StatefulOperationRequest & Sendable>(
  ///      for operation: Operation,
  ///      in context: OperationContext,
  ///      with initialState: Operation.State
  ///    ) -> OperationStore<Operation.State> {
  ///      if operation is any MutationRequest {
  ///        // Modifiers applied only to mutations
  ///        return .detached(
  ///          operation: operation.retry(limit: 3),
  ///          initialState: initialState,
  ///          initialContext: context
  ///        )
  ///      }
  ///      // Modifiers applied only to all other operations
  ///      return .detached(
  ///        operation: operation.retry(limit: 3)
  ///          .enableAutomaticRunning(onlyWhen: .always(true))
  ///          .customModifier()
  ///          .deduplicated(),
  ///        initialState: initialState,
  ///        initialContext: context
  ///      )
  ///    }
  ///  }
  /// ```
  /// Read <doc:OperationDefaults> to learn more about how to set defaults for your operations.
  public protocol StoreCreator {
    /// Creates a ``OperationStore`` for the specified ``OperationRequest``.
    ///
    /// - Parameters:
    ///   - operation: The operation.
    ///   - context: The initial ``OperationContext`` of the store.
    ///   - initialState: The initial state of the operation.
    /// - Returns: A ``OperationStore``.
    func store<Operation: StatefulOperationRequest>(
      for operation: sending Operation,
      in context: OperationContext,
      with initialState: Operation.State
    ) -> OperationStore<Operation.State>
  }
}

// MARK: - CreateStore

extension OperationClient {
  /// A data type that creates ``OperationStore`` instances from within the closure of
  /// ``OperationClient/withStores(matching:of:perform:)``.
  ///
  /// Use this type to add `OperationStore` instances to an `OperationClient` when performing bulk edit
  /// operations on the stores within the client.
  ///
  /// ```swift
  /// let client: OperationClient
  /// let users: [User]
  ///
  /// // ...
  ///
  /// client.withStores(
  ///   matching: ["users"],
  ///   of: User.Query.State.self
  /// ) { stores, createStore in
  ///   // ...
  ///   for user in users {
  ///     stores.update(
  ///       createStore(for: User.query(id: user.id), initialValue: user)
  ///     )
  ///   }
  /// }
  /// ```
  public struct CreateStore: ~Copyable {
    let creator: any OperationClient.StoreCreator
    let initialContext: OperationContext
    let operationTypes: MutableBox<[OperationPath: Any.Type]>
  }
}

extension OperationClient.CreateStore {
  /// Creates a ``OperationStore`` for a ``StatefulOperationRequest``.
  ///
  /// - Parameters:
  ///   - operation: The operation,.
  ///   - initialState: The initial state of the operation.
  /// - Returns: An ``OperationStore``.
  public func callAsFunction<Operation: StatefulOperationRequest>(
    for operation: sending Operation,
    initialState: Operation.State
  ) -> OperationStore<Operation.State> {
    self.operationTypes.value[operation.path] = Operation.self
    return self.creator.store(for: operation, in: self.initialContext, with: initialState)
  }

  /// Creates a ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialState: The initial state of the query.
  /// - Returns: A ``OperationStore``.
  @_disfavoredOverload
  public func callAsFunction<Query: QueryRequest>(
    for query: sending Query,
    initialState: Query.State
  ) -> OperationStore<Query.State> {
    self(for: query, initialState: initialState)
  }

  /// Creates a ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value of the query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: QueryRequest>(
    for query: sending Query,
    initialValue: Query.Value? = nil
  ) -> OperationStore<Query.State> where Query.State == QueryState<Query.Value, Query.Failure> {
    self(for: query, initialState: Query.State(initialValue: initialValue))
  }

  /// Creates a ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: QueryRequest>(
    for query: sending Query.Default
  ) -> OperationStore<Query.Default.State> {
    self(for: query, initialState: query.initialState)
  }

  /// Creates a ``OperationStore`` for a ``PaginatedRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value for the state of the query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: PaginatedRequest>(
    for query: sending Query,
    initialValue: Query.State.StateValue = []
  ) -> OperationStore<Query.State> {
    self(
      for: query,
      initialState: PaginatedState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      )
    )
  }

  /// Creates a ``OperationStore`` for a ``PaginatedRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: PaginatedRequest>(
    for query: sending Query.Default
  ) -> OperationStore<Query.Default.State> {
    self(for: query, initialState: query.initialState)
  }

  /// Creates a ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - query: The mutation.
  ///   - initialValue: The initial value for the state of the mutation.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Mutation: MutationRequest>(
    for mutation: sending Mutation,
    initialValue: Mutation.MutateValue? = nil
  ) -> OperationStore<Mutation.State> {
    self(for: mutation, initialState: Mutation.State(initialValue: initialValue))
  }

  /// Creates a ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - query: The mutation.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Mutation: MutationRequest>(
    for mutation: sending Mutation.Default,
  ) -> OperationStore<Mutation.Default.State> {
    self(for: mutation, initialState: mutation.initialState)
  }
}
