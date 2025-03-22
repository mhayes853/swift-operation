// MARK: - OpaqueQueryEventHandler

public struct OpaqueQueryEventHandler: Sendable {
  let onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  let onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  let onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)?

  public init(
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)? = nil
  ) {
    self.onFetchingEnded = onFetchingEnded
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
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
      }
    )
  }
}
