func removeDuplicateInfiniteQueries<Query: InfiniteQueryRequest>(
  _ c1: QueryContext,
  _ c2: QueryContext,
  using query: Query
) -> Bool {
  c1.paging(for: query).request == c2.paging(for: query).request
}
