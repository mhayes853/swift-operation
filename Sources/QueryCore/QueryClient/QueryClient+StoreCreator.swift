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
  public protocol StoreCreator: Sendable {
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
