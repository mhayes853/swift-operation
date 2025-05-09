// MARK: - OpaqueQueryEventHandler

/// An event handler that is passed to ``OpaqueQueryStore/subscribe(with:)``.
public struct OpaqueQueryEventHandler: Sendable {
  /// A callback that is invoked when the state changes.
  public var onStateChanged: (@Sendable (OpaqueQueryState, QueryContext) -> Void)?
  
  /// A callback that is invoked when fetching begins on the ``OpaqueQueryStore``.
  public var onFetchingStarted: (@Sendable (QueryContext) -> Void)?
  
  /// A callback that is invoked when fetching ends on the ``OpaqueQueryStore``.
  public var onFetchingEnded: (@Sendable (QueryContext) -> Void)?
  
  /// A callback that is invoked when a result is received from fetching on a ``OpaqueQueryStore``.
  public var onResultReceived: (@Sendable (Result<any Sendable, any Error>, QueryContext) -> Void)?
  
  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the state changes.
  ///   - onFetchingStarted: A callback that is invoked when fetching begins on the ``OpaqueQueryStore``.
  ///   - onFetchingEnded: A callback that is invoked when fetching ends on the ``OpaqueQueryStore``.
  ///   - onResultReceived: A callback that is invoked when a result is received from fetching on a ``OpaqueQueryStore``.
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
