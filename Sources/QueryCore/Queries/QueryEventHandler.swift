// MARK: - QueryEventHandler

public struct QueryEventHandler<State: QueryStateProtocol>: Sendable {
  public var onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  public var onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  public var onResultReceived:
    (@Sendable (Result<State.QueryValue, any Error>, QueryContext) -> Void)?
  public var onStateChanged: (@Sendable (State, QueryContext) -> Void)?

  public init(
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<State.QueryValue, any Error>, QueryContext) -> Void)? =
      nil,
    onStateChanged: (@Sendable (State, QueryContext) -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
    self.onStateChanged = onStateChanged
  }
}
