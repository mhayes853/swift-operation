// MARK: - OpaqueOperationEventHandler

/// An event handler that handles events from ``OpaqueOperationStore``.
///
/// Events include state changes, yielded/returned results, and detection for when an
/// operation run begins and ends.
public struct OpaqueOperationEventHandler: Sendable {
  /// A callback that is invoked when the state changes.
  public var onStateChanged: (@Sendable (OpaqueOperationState, OperationContext) -> Void)?

  /// A callback that is invoked when an operation run begins.
  ///
  /// This callback is invoked after immediately after an ``OperationStore`` calls
  /// ``OperationRequest/run(isolation:in:with:)``.
  public var onRunStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when an operation run ends.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onRunEnded: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when a result is received from an operation.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``. If you want
  /// to be alerted to state changes, you can listen to them in ``onStateChanged``.
  public var onResultReceived:
    (@Sendable (Result<any Sendable, any Error>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the state changes.
  ///   - onRunStarted: A callback that is invoked when an operation run begins.
  ///   - onRunEnded: A callback that is invoked when an operation run ends.
  ///   - onResultReceived: A callback that is invoked when a result is received from an operation.
  public init(
    onStateChanged: (@Sendable (OpaqueOperationState, OperationContext) -> Void)? = nil,
    onRunStarted: (@Sendable (OperationContext) -> Void)? = nil,
    onRunEnded: (@Sendable (OperationContext) -> Void)? = nil,
    onResultReceived: (
      @Sendable (Result<any Sendable, any Error>, OperationContext) -> Void
    )? = nil
  ) {
    self.onRunEnded = onRunEnded
    self.onRunStarted = onRunStarted
    self.onResultReceived = onResultReceived
    self.onStateChanged = onStateChanged
  }
}

// MARK: - Casting

extension OpaqueOperationEventHandler {
  func casted<State: OperationState & Sendable>(
    to stateType: State.Type
  ) -> OperationEventHandler<State> {
    OperationEventHandler<State>(
      onStateChanged: { state, context in
        self.onStateChanged?(OpaqueOperationState(state), context)
      },
      onRunStarted: self.onRunStarted,
      onRunEnded: self.onRunEnded,
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
