func removeDuplicateInfiniteQueries<Query: InfiniteQueryRequest>(
  _ info1: QueryRequestDeuplicateableInfo,
  _ info2: QueryRequestDeuplicateableInfo,
  using query: Query
) -> Bool {
  info1.context.paging(for: query).request == info2.context.paging(for: query).request
}
