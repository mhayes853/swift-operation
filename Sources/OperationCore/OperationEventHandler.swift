// MARK: - OperationEventHandler

/// An event handler that is passed to ``OperationStore/subscribe(with:)-93jyd``.
public struct OperationEventHandler<State: OperationState>: Sendable {
  /// A callback that is invoked when the operation state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when fetching begins on the ``OperationStore``.
  public var onFetchingStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when fetching ends on the ``OperationStore``.
  public var onFetchingEnded: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when a result is received from fetching on a ``OperationStore``.
  public var onResultReceived:
    (@Sendable (Result<State.OperationValue, any Error>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the operation state changes.
  ///   - onFetchingStarted: A callback that is invoked when fetching begins on the ``OperationStore``.
  ///   - onFetchingEnded: A callback that is invoked when fetching ends on the ``OperationStore``.
  ///   - onResultReceived: A callback that is invoked when a result is received from fetching on a ``OperationStore``.
  public init(
    onStateChanged: (@Sendable (State, OperationContext) -> Void)? = nil,
    onFetchingStarted: (@Sendable (OperationContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (OperationContext) -> Void)? = nil,
    onResultReceived: (
      @Sendable (Result<State.OperationValue, any Error>, OperationContext) -> Void
    )? =
      nil
  ) {
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onFetchingEnded = onFetchingEnded
    self.onStateChanged = onStateChanged
  }
}
