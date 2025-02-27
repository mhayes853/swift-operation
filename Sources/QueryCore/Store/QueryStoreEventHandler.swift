public struct QueryStoreEventHandler<Value: Sendable>: Sendable {
  let onFetchingStarted: (@Sendable () -> Void)?
  let onFetchingEnded: (@Sendable () -> Void)?
  let onResultReceived: (@Sendable (Result<Value, any Error>) -> Void)?

  public init(
    onFetchingStarted: (@Sendable () -> Void)? = nil,
    onFetchingEnded: (@Sendable () -> Void)? = nil,
    onResultReceived: (@Sendable (Result<Value, any Error>) -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
  }
}
