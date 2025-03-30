import QueryCore

@MainActor
extension QueryClient {
  public func model<Query: QueryRequest>(
    for query: Query,
    initialState: Query.State
  ) -> QueryModel<Query.State> where Query.Value == Query.State.QueryValue {
    QueryModel(store: self.store(for: query, initialState: initialState))
  }

  public func model<Query: QueryRequest>(for query: Query) -> QueryModel<Query.State>
  where Query.State == QueryState<Query.Value?, Query.Value> {
    QueryModel(store: self.store(for: query))
  }

  public func model<Query: QueryRequest>(
    for query: DefaultQuery<Query>
  ) -> QueryModel<DefaultQuery<Query>.State>
  where DefaultQuery<Query>.State == QueryState<Query.Value, Query.Value> {
    QueryModel(store: self.store(for: query))
  }

  public func model<Query: InfiniteQueryRequest>(
    for query: Query
  ) -> QueryModel<Query.State> {
    QueryModel(store: self.store(for: query).base)
  }

  public func model<Query: InfiniteQueryRequest>(
    for query: DefaultInfiniteQuery<Query>
  ) -> QueryModel<DefaultInfiniteQuery<Query>.State> {
    QueryModel(store: self.store(for: query).base)
  }

  public func model<Mutation: MutationRequest>(
    for mutation: Mutation
  ) -> QueryModel<Mutation.State> {
    QueryModel(store: self.store(for: mutation).base)
  }
}
