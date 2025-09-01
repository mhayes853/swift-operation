import IdentifiedCollections

/// An event handler that is passed to ``OperationStore/subscribe(with:)-7a55v``.
public struct PaginatedEventHandler<State: _PaginatedStateProtocol>: Sendable {
  /// A callback that is invoked when the query state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when fetching starts.
  public var onFetchingStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when fetching for a specified page starts.
  public var onPageFetchingStarted: (@Sendable (State.PageID, OperationContext) -> Void)?

  /// A callback that is invoked when the result for fetching a page is received.
  public var onPageResultReceived:
    (
      @Sendable (
        State.PageID,
        Result<Page<State.PageID, State.PageValue>, State.Failure>,
        OperationContext
      ) -> Void
    )?

  /// A callback that is invoked when a result is received from fetching on a ``OperationStore``.
  public var onResultReceived:
    (
      @Sendable (
        Result<Pages<State.PageID, State.PageValue>, State.Failure>,
        OperationContext
      ) -> Void
    )?

  /// A callback that is invoked when fetching for a specified page ends.
  public var onPageFetchingEnded: (@Sendable (State.PageID, OperationContext) -> Void)?

  /// A callback that is invoked when fetching ends.
  public var onFetchingEnded: (@Sendable (OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the query state changes.
  ///   - onFetchingStarted: A callback that is invoked when fetching starts.
  ///   - onPageFetchingStarted: A callback that is invoked when fetching for a specified page starts.
  ///   - onPageResultReceived: A callback that is invoked when the result for fetching a page is received.
  ///   - onResultReceived: A callback that is invoked when a result is received from fetching on a ``OperationStore``.
  ///   - onPageFetchingEnded: A callback that is invoked when fetching for a specified page ends.
  ///   - onFetchingEnded: A callback that is invoked when fetching ends.
  public init(
    onStateChanged: (@Sendable (State, OperationContext) -> Void)? = nil,
    onFetchingStarted: (@Sendable (OperationContext) -> Void)? = nil,
    onPageFetchingStarted: (@Sendable (State.PageID, OperationContext) -> Void)? = nil,
    onPageResultReceived: (
      @Sendable (
        State.PageID,
        Result<Page<State.PageID, State.PageValue>, State.Failure>,
        OperationContext
      ) -> Void
    )? = nil,
    onResultReceived: (
      @Sendable (
        Result<Pages<State.PageID, State.PageValue>, State.Failure>,
        OperationContext
      ) -> Void
    )? = nil,
    onPageFetchingEnded: (@Sendable (State.PageID, OperationContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (OperationContext) -> Void)? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onPageFetchingStarted = onPageFetchingStarted
    self.onPageResultReceived = onPageResultReceived
    self.onResultReceived = onResultReceived
    self.onPageFetchingEnded = onPageFetchingEnded
    self.onFetchingEnded = onFetchingEnded
    self.onStateChanged = onStateChanged
  }
}
