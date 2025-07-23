// MARK: - StoreCreator

extension QueryClient {
  /// A protocol that controls how a ``QueryClient`` creates ``QueryStore`` instances.
  ///
  /// Conform to this protocol when you want to apply custom modifiers by default to all of your
  /// queries.
  /// ```swift
  /// struct MyStoreCreator: QueryClient.StoreCreator {
  ///    func store<Query: QueryRequest>(
  ///      for query: Query,
  ///      in context: QueryContext,
  ///      with initialState: Query.State
  ///    ) -> QueryStore<Query.State> {
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
    /// Creates a ``QueryStore`` for the specified ``QueryRequest``.
    ///
    /// - Parameters:
    ///   - query: The query.
    ///   - context: The initial ``QueryContext`` of the store.
    ///   - initialState: The initial state of the query.
    /// - Returns: A ``QueryStore``.
    func store<Query: QueryRequest>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State>
  }
}

// MARK: - CreateStore

extension QueryClient {
  /// A data type that creates ``QueryStore`` instances from within the closure of
  /// ``QueryClient/withStores(matching:of:perform:)``.
  ///
  /// Use this type to add `QueryStore` instances to a `QueryClient` when performing bulk edit
  /// operations on the stores within the client.
  ///
  /// ```swift
  /// let client: QueryClient
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
    let creator: any QueryClient.StoreCreator
    let initialContext: QueryContext
    var queryTypes: [QueryPath: Any.Type]
  }
}

extension QueryClient.CreateStore {
  /// Creates a ``QueryStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialState: The initial state of the query.
  /// - Returns: A ``QueryStore``.
  public mutating func callAsFunction<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> QueryStore<Query.State> {
    self.queryTypes[query.path] = Query.self
    return self.creator.store(for: query, in: self.initialContext, with: initialState)
  }

  /// Creates a ``QueryStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value of the query.
  /// - Returns: A ``QueryStore``.
  public mutating func callAsFunction<Query: QueryRequest>(
    for query: Query,
    initialValue: Query.Value? = nil
  ) -> QueryStore<Query.State>
  where Query.State == QueryState<Query.Value?, Query.Value> {
    self(for: query, initialState: Query.State(initialValue: initialValue))
  }

  /// Creates a ``QueryStore`` for a ``QueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``QueryStore``.
  public mutating func callAsFunction<Query: QueryRequest>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<DefaultQuery<Query>.State>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    self(for: query, initialState: DefaultQuery<Query>.State(initialValue: query.defaultValue))
  }

  /// Creates a ``QueryStore`` for an ``InfiniteQueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  ///   - initialValue: The initial value for the state of the query.
  /// - Returns: A ``QueryStore``.
  public mutating func callAsFunction<Query: InfiniteQueryRequest>(
    for query: Query,
    initialValue: Query.State.StateValue = []
  ) -> QueryStore<Query.State> {
    self(
      for: query,
      initialState: InfiniteQueryState(
        initialValue: initialValue,
        initialPageId: query.initialPageId
      )
    )
  }

  /// Creates a ``QueryStore`` for an ``InfiniteQueryRequest``.
  ///
  /// - Parameters:
  ///   - query: The query.
  /// - Returns: A ``QueryStore``.
  public mutating func callAsFunction<Query: InfiniteQueryRequest>(
    for query: DefaultInfiniteQuery<Query>
  ) -> QueryStore<DefaultInfiniteQuery<Query>.State> {
    self(
      for: query,
      initialState: InfiniteQueryState(
        initialValue: query.defaultValue,
        initialPageId: query.initialPageId
      )
    )
  }

  /// Creates a ``QueryStore`` for a ``MutationRequest``.
  ///
  /// - Parameters:
  ///   - query: The mutation.
  ///   - initialValue: The initial value for the state of the mutation.
  /// - Returns: A ``QueryStore``.
  public mutating func callAsFunction<Mutation: MutationRequest>(
    for mutation: Mutation,
    initialValue: Mutation.State.StateValue = nil
  ) -> QueryStore<Mutation.State> {
    self(for: mutation, initialState: MutationState(initialValue: initialValue))
  }
}
