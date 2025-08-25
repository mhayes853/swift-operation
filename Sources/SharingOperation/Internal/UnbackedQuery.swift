@_spi(Warnings) import Operation

// MARK: - UnbackedQuery

struct UnbackedQuery<State: QueryStateProtocol>: QueryRequest {
  let path = QueryPath("__sharing_query_unbacked_query_\(typeName(State.self))__")

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<State.QueryValue>
  ) async throws -> State.QueryValue {
    reportWarning(.unbackedQueryFetch(type: State.self))
    throw UnbackedQueryError()
  }
}

private struct UnbackedQueryError: Error {}

// MARK: - Warning

extension QueryWarning {
  public static func unbackedQueryFetch(type: Any.Type) -> Self {
    """
    An unbacked shared query attempted to fetch its data. Doing so has no effect on the value of \
    the query.

        Query State Type: \(typeName(type))
    """
  }
}
