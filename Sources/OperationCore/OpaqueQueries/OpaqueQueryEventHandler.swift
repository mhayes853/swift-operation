// MARK: - OpaqueOperationEventHandler

/// An event handler that is passed to ``OpaqueOperationStore/subscribe(with:)``.
public struct OpaqueOperationEventHandler: Sendable {
  /// A callback that is invoked when the state changes.
  public var onStateChanged: (@Sendable (OpaqueOperationState, OperationContext) -> Void)?

  /// A callback that is invoked when fetching begins on the ``OpaqueOperationStore``.
  public var onFetchingStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when fetching ends on the ``OpaqueOperationStore``.
  public var onFetchingEnded: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when a result is received from fetching on a ``OpaqueOperationStore``.
  public var onResultReceived:
    (@Sendable (Result<any Sendable, any Error>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the state changes.
  ///   - onFetchingStarted: A callback that is invoked when fetching begins on the ``OpaqueOperationStore``.
  ///   - onFetchingEnded: A callback that is invoked when fetching ends on the ``OpaqueOperationStore``.
  ///   - onResultReceived: A callback that is invoked when a result is received from fetching on a ``OpaqueOperationStore``.
  public init(
    onStateChanged: (@Sendable (OpaqueOperationState, OperationContext) -> Void)? = nil,
    onFetchingStarted: (@Sendable (OperationContext) -> Void)? = nil,
    onFetchingEnded: (@Sendable (OperationContext) -> Void)? = nil,
    onResultReceived: (@Sendable (Result<any Sendable, any Error>, OperationContext) -> Void)? = nil
  ) {
    self.onFetchingEnded = onFetchingEnded
    self.onFetchingStarted = onFetchingStarted
    self.onResultReceived = onResultReceived
    self.onStateChanged = onStateChanged
  }
}

// MARK: - Casting

extension OpaqueOperationEventHandler {
  func casted<State: OperationState>(
    to stateType: State.Type
  ) -> OperationEventHandler<State> {
    OperationEventHandler<State>(
      onStateChanged: { state, context in
        self.onStateChanged?(OpaqueOperationState(state), context)
      },
      onFetchingStarted: self.onFetchingStarted,
      onFetchingEnded: self.onFetchingEnded,
      onResultReceived: { result, context in
        switch result {
        case .success(let value):
          self.onResultReceived?(.success(value), context)
        case .failure(let error):
          self.onResultReceived?(.failure(error), context)
        }
      }
    )
  }
}
