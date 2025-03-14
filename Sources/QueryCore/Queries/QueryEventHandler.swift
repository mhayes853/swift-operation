// MARK: - QueryEventHandler

public struct QueryEventHandler<Value: Sendable>: Sendable {
  let onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  let onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  let onResultReceived: (@Sendable (Result<Value, any Error>, QueryContext) -> Void)?

  public init(
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<Value, any Error>, QueryContext) -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
  }
}
