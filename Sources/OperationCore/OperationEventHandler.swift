// MARK: - OperationEventHandler

/// An event handler that handles events from a ``StatefulOperationRequest``.
///
/// Events include state changes, yielded/returned results, and detection for when an
/// operation run begins and ends. Both ``OperationStore`` and the
/// ``StatefulOperationRequest/handleEvents(with:)`` modifier use event handlers to notify you when
/// these events occur. Furthermore, `OperationStore` automatically applies the `handleEvents`
/// modifier to your operation so you can observe events through
/// ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``.
public struct OperationEventHandler<State: OperationState>: Sendable {
  /// A callback that is invoked when the operation state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when an operation run begins.
  ///
  /// This callback is invoked after immediately after an ``OperationStore`` calls
  /// ``OperationRequest/run(isolation:in:with:)``.
  public var onRunStarted: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when an operation run ends.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``.
  public var onRunEnded: (@Sendable (OperationContext) -> Void)?

  /// A callback that is invoked when a result is received from an operation run.
  ///
  /// This callback is invoked before any state changes occur on an ``OperationStore``.
  public var onResultReceived:
    (@Sendable (Result<State.OperationValue, State.Failure>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the operation state changes.
  ///   - onRunStarted: A callback that is invoked when an operation run begins.
  ///   - onRunEnded: A callback that is invoked when an operation run ends.
  ///   - onResultReceived: A callback that is invoked when a result is received from an operation run.
  public init(
    onStateChanged: (@Sendable (State, OperationContext) -> Void)? = nil,
    onRunStarted: (@Sendable (OperationContext) -> Void)? = nil,
    onRunEnded: (@Sendable (OperationContext) -> Void)? = nil,
    onResultReceived: (
      @Sendable (Result<State.OperationValue, State.Failure>, OperationContext) -> Void
    )? = nil
  ) {
    self.onRunStarted = onRunStarted
    self.onResultReceived = onResultReceived
    self.onRunEnded = onRunEnded
    self.onStateChanged = onStateChanged
  }
}
