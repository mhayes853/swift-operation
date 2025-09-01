func removeDuplicatePaginatedRequests<Query: PaginatedRequest>(
  _ c1: OperationContext,
  _ c2: OperationContext,
  using query: Query
) -> Bool {
  c1.paging(for: query).request == c2.paging(for: query).request
}
