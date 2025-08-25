@_spi(Warnings) import Operation

// MARK: - UnbackedQuery

struct UnbackedQuery<State: OperationState>: QueryRequest {
  let path = OperationPath("__sharing_query_unbacked_query_\(typeName(State.self))__")

  func fetch(
    in context: OperationContext,
    with continuation: OperationContinuation<State.OperationValue>
  ) async throws -> State.OperationValue {
    reportWarning(.unbackedQueryFetch(type: State.self))
    throw UnbackedQueryError()
  }
}

private struct UnbackedQueryError: Error {}

// MARK: - Warning

extension OperationWarning {
  public static func unbackedQueryFetch(type: Any.Type) -> Self {
    """
    An unbacked shared query attempted to fetch its data. Doing so has no effect on the value of \
    the query.

        State Type: \(typeName(type))
    """
  }
}
