public typealias OpaqueQueryEventHandler = QueryEventHandler<any Sendable>

extension OpaqueQueryEventHandler {
  func casted<V: Sendable>(to value: V.Type) -> QueryEventHandler<V> {
    QueryEventHandler<V>(
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
