public final class QueryClient: Sendable {
  public init() {}
}

extension QueryClient {
  public func store<Query: QueryProtocol>(for query: Query) -> QueryStore<Query.Value?> {
    QueryStore(query: query)
  }

  public func store<Query: QueryProtocol>(
    for query: DefaultQuery<Query>
  ) -> QueryStore<Query.Value> {
    QueryStore(query: query)
  }
}
