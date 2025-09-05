func removeDuplicatePaginatedRequests<State: _PaginatedStateProtocol & Sendable>(
  _ c1: OperationContext,
  _ c2: OperationContext,
  _: State.Type
) -> Bool {
  c1.request(State.self) == c2.request(State.self)
}
