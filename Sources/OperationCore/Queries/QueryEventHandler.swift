// MARK: - QueryEventHandler

/// An event handler that handles events from ``QueryRequest``.
///
/// Events include state changes, yielded/returned results, and detection for when an
/// operation run begins and ends.
public struct QueryEventHandler<State: _QueryStateProtocol>: Sendable {
  /// A callback that is invoked when the query state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when query fetching begins.
  ///
  /// This callback is invoked after immediately after an ``OperationStore`` calls
  /// ``OperationRequest/run(isolation:in:with:)``.
  public var onFetchingStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when query fetching ends.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onFetchingEnded: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when a result is received from query fetching.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onResultReceived:
    (@Sendable (Result<State.OperationValue, State.Failure>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the query state changes.
  ///   - onFetchingStarted: A callback that is invoked when query fetching begins.
  ///   - onFetchingEnded: A callback that is invoked when query fetching ends.
  ///   - onResultReceived: A callback that is invoked when a result is received from query fetching.
  public init(
    onStateChanged: (@Sendable (State, OperationContext) -> Void)? = nil,
    onFetchingStarted: (@Sendable (OperationContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (OperationContext) -> Void)? = nil,
    onResultReceived: (
      @Sendable (Result<State.OperationValue, State.Failure>, OperationContext) -> Void
    )? = nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
    self.onStateChanged = onStateChanged
  }
}
