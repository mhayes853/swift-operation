// MARK: - StoreCreator

extension OperationClient {
  /// A protocol that controls how a ``OperationClient`` creates ``OperationStore`` instances.
  ///
  /// Conform to this protocol when you want to apply custom modifiers by default to all of your
  /// queries.
  /// ```swift
  /// struct MyStoreCreator: OperationClient.StoreCreator {
  ///    func store<Query: QueryRequest>(
  ///      for query: Query,
  ///      in context: OperationContext,
  ///      with initialState: Query.State
  ///    ) -> OperationStore<Query.State> {
  ///      if query is any MutationRequest {
  ///        // Modifiers applied only to mutations
  ///        return .detached(
  ///          query: query.retry(limit: 3),
  ///          initialState: initialState,
  ///          initialContext: context
  ///        )
  ///      }
  ///      // Modifiers applied only to queries and infinite queries
  ///      return .detached(
  ///        query: query.retry(limit: 3)
  ///          .enableAutomaticFetching(onlyWhen: .always(true))
  ///          .customModifier()
  ///          .deduplicated(),
  ///        initialState: initialState,
  ///        initialContext: context
  ///      )
  ///    }
  ///  }
  /// ```
  /// Read <doc:QueryDefaults> to learn more about how to set defaults for your queries.
  public protocol StoreCreator {
    /// Creates a ``OperationStore`` for the specified ``QueryRequest``.
    ///
    /// - Parameters:
    ///   - query: The query.
    ///   - context: The initial ``OperationContext`` of the store.
    ///   - initialState: The initial state of the query.
    /// - Returns: A ``OperationStore``.
    func store<Query: QueryRequest>(
      for query: Query,
      in context: OperationContext,
      with initialState: Query.State
    ) -> OperationStore<Query.State>
  }
}

// MARK: - CreateStore

extension OperationClient {
  /// A data type that creates ``OperationStore`` instances from within the closure of
  /// ``OperationClient/withStores(matching:of:perform:)``.
  ///
  /// Use this type to add `OperationStore` instances to a `OperationClient` when performing bulk edit
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
    let queryTypes: MutableBox<[OperationPath: Any.Type]>
  }
}

extension OperationClient.CreateStore {
  /// Creates a ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialState: The initial state of the query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> OperationStore<Query.State> {
    self.queryTypes.value[query.path] = Query.self
    return self.creator.store(for: query, in: self.initialContext, with: initialState)
  }

  /// Creates a ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value of the query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: QueryRequest>(
    for query: Query,
    initialValue: Query.Value? = nil
  ) -> OperationStore<Query.State>
  where Query.State == QueryState<Query.Value?, Query.Value> {
    self(for: query, initialState: Query.State(initialValue: initialValue))
  }

  /// Creates a ``OperationStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: QueryRequest>(
    for query: DefaultQuery<Query>
  ) -> OperationStore<DefaultQuery<Query>.State>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    self(for: query, initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue))
  }

  /// Creates a ``OperationStore`` for an ``InfiniteQueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value for the state of the query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: InfiniteQueryRequest>(
    for query: Query,
    initialValue: Query.State.StateValue = []
  ) -> OperationStore<Query.State> {
    self(
      for: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      )
    )
  }

  /// Creates a ``OperationStore`` for an ``InfiniteQueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Query: InfiniteQueryRequest>(
    for query: DefaultInfiniteQuery<Query>
  ) -> OperationStore<DefaultInfiniteQuery<Query>.State> {
    self(
      for: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      )
    )
  }

  /// Creates a ``OperationStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - query: The mutation.
  ///   - initialValue: The initial value for the state of the mutation.
  /// - Returns: A ``OperationStore``.
  public func callAsFunction<Mutation: MutationRequest>(
    for mutation: Mutation,
    initialValue: Mutation.State.StateValue = nil
  ) -> OperationStore<Mutation.State> {
    self(for: mutation, initialState: MutationState(initialValue: initialValue))
  }
}
