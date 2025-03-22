// MARK: - OpaqueQueryEventHandler

public struct OpaqueQueryEventHandler: Sendable {
  let onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  let onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  let onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)?
  let onStateChanged: (@Sendable (OpaqueQueryState, QueryContext) -> Void)?

  public init(
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)? = nil,
    onStateChanged: (@Sendable (OpaqueQueryState, QueryContext) -> Void)? = nil
  ) {
    self.onFetchingEnded = onFetchingEnded
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onStateChanged = onStateChanged
  }
}

// MARK: - Casting

extension OpaqueQueryEventHandler {
  func casted<State: QueryStateProtocol>(to stateType: State.Type) -> QueryEventHandler<State> {
    QueryEventHandler<State>(
      onFetchingStarted: self.onFetchingStarted,
      onFetchingEnded: self.onFetchingEnded,
      onResultReceived: { result, context in
        switch result {
        case let .success(value):
          self.onResultReceived?(.success(value), context)
        case let .failure(error):
          self.onResultReceived?(.failure(error), context)
        }
      },
      onStateChanged: { state, context in
        self.onStateChanged?(OpaqueQueryState(state), context)
      }
    )
  }
}
