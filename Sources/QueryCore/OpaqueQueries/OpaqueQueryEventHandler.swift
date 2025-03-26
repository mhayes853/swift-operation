// MARK: - OpaqueQueryEventHandler

public struct OpaqueQueryEventHandler: Sendable {
  public var onStateChanged: (@Sendable (OpaqueQueryState, QueryContext) -> Void)?
  public var onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  public var onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  public var onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)?

  public init(
    onStateChanged: (@Sendable (OpaqueQueryState, QueryContext) -> Void)? = nil,
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)? = nil
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
      onStateChanged: { state, context in
        self.onStateChanged?(OpaqueQueryState(state), context)
      },
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
