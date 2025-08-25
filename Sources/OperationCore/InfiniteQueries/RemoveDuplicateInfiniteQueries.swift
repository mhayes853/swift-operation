func removeDuplicateInfiniteQueries<Query: InfiniteQueryRequest>(
  _ c1: OperationContext,
  _ c2: OperationContext,
  using query: Query
) -> Bool {
  c1.paging(for: query).request == c2.paging(for: query).request
}
