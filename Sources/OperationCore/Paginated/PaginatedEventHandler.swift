import IdentifiedCollections

/// An event handler that handles events from ``PaginatedRequest``.
///
/// Events include state changes, yielded/returned results, and detection for when an
/// operation run begins and ends.
public struct PaginatedEventHandler<State: _PaginatedStateProtocol>: Sendable {
  /// A callback that is invoked when the query state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when fetching starts.
  ///
  /// This callback is invoked after immediately after an ``OperationStore`` calls
  /// ``OperationRequest/run(isolation:in:with:)``.
  public var onFetchingStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when fetching for a specified page starts.
  public var onPageFetchingStarted: (@Sendable (State.PageID, OperationContext) -> Void)?

  /// A callback that is invoked when the result is received from fetching a specified page.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onPageResultReceived:
    (
      @Sendable (
        State.PageID,
        Result<Page<State.PageID, State.PageValue>, State.Failure>,
        OperationContext
      ) -> Void
    )?

  /// A callback that is invoked when a result is received from fetching.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onResultReceived:
    (
      @Sendable (
        Result<Pages<State.PageID, State.PageValue>, State.Failure>,
        OperationContext
      ) -> Void
    )?

  /// A callback that is invoked when fetching for a specified page ends.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onPageFetchingEnded: (@Sendable (State.PageID, OperationContext) -> Void)?

  /// A callback that is invoked when fetching ends.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onFetchingEnded: (@Sendable (OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the query state changes.
  ///   - onFetchingStarted: A callback that is invoked when fetching starts.
  ///   - onPageFetchingStarted: A callback that is invoked when fetching for a specified page starts.
  ///   - onPageResultReceived: A callback that is invoked when the result is received from fetching a specified page.
  ///   - onResultReceived: A callback that is invoked when a result is received from fetching.
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
