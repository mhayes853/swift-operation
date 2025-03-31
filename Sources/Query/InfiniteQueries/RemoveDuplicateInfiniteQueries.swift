func removeDuplicateInfiniteQueries<Query: InfiniteQueryRequest>(
  _ info1: QueryTaskInfo,
  _ info2: QueryTaskInfo,
  using query: Query
) -> Bool {
  info1.configuration.context.paging(for: query).request
    == info2.configuration.context.paging(for: query).request
}
