// MARK: - QueryEventHandler

/// An event handler that is passed to ``QueryStore/subscribe(with:)-93jyd``.
public struct QueryEventHandler<State: QueryStateProtocol>: Sendable {
  /// A callback that is invoked when the query state changes.
  public var onStateChanged: (@Sendable (State, QueryContext) -> Void)?

  /// A callback that is invoked when fetching begins on the ``QueryStore``.
  public var onFetchingStarted: (@Sendable (QueryContext) -> Void)?

  /// A callback that is invoked when fetching ends on the ``QueryStore``.
  public var onFetchingEnded: (@Sendable (QueryContext) -> Void)?

  /// A callback that is invoked when a result is received from fetching on a ``QueryStore``.
  public var onResultReceived:
    (@Sendable (Result<State.QueryValue, any Error>, QueryContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the query state changes.
  ///   - onFetchingStarted: A callback that is invoked when fetching begins on the ``QueryStore``.
  ///   - onFetchingEnded: A callback that is invoked when fetching ends on the ``QueryStore``.
  ///   - onResultReceived: A callback that is invoked when a result is received from fetching on a ``QueryStore``.
  public init(
    onStateChanged: (@Sendable (State, QueryContext) -> Void)? = nil,
    onFetchingStarted: (@Sendable (QueryContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (QueryContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<State.QueryValue, any Error>, QueryContext) -> Void)? =
      nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
    self.onStateChanged = onStateChanged
  }
}
