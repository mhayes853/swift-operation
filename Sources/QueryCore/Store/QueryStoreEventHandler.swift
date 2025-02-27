// MARK: - QueryStoreEventHandler

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

// MARK: - Casting

extension QueryStoreEventHandler {
  func unsafeCasted<NewValue: Sendable>(
    to newValueType: NewValue.Type
  ) -> QueryStoreEventHandler<NewValue> {
    QueryStoreEventHandler<NewValue>(
      onFetchingStarted: self.onFetchingStarted,
      onFetchingEnded: self.onFetchingEnded,
      onResultReceived: { result in
        switch result {
        case let .success(value):
          self.onResultReceived?(.success(value as! Value))
        case let .failure(error):
          self.onResultReceived?(.failure(error))
        }
      }
    )
  }
}
