// MARK: - QueryEventHandler

public struct QueryEventHandler<State: QueryStateProtocol>: Sendable {
  let onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  let onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  let onResultReceived: (@Sendable (Result<State.QueryValue, any Error>, QueryContext) -> Void)?
  let onStateChanged: (@Sendable (QueryContext) -> Void)?

  public init(
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<State.QueryValue, any Error>, QueryContext) -> Void)? =
      nil,
    onStateChanged: (@Sendable (QueryContext) -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
    self.onStateChanged = onStateChanged
  }
}
