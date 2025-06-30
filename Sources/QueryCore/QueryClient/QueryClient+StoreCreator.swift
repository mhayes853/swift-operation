extension QueryClient {
  public protocol StoreCreator: Sendable {
    func store<Query: QueryRequest>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State>
  }
}
