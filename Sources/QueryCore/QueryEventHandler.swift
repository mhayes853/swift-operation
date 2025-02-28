// MARK: - QueryEventHandler

public struct QueryEventHandler<Value: Sendable>: Sendable {
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

// MARK: - Casting

extension QueryEventHandler {
  func erased() -> QueryEventHandler<any Sendable> {
    QueryEventHandler<any Sendable>(
      onFetchingStarted: onFetchingStarted,
      onFetchingEnded: onFetchingEnded,
      onResultReceived: { result in
        switch result {
        case let .success(value):
          onResultReceived?(.success(value as! Value))
        case let .failure(error):
          onResultReceived?(.failure(error))
        }
      }
    )
  }
}
