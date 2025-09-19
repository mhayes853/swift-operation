/// An event handler that handles events from ``MutationRequest``.
///
/// Events include state changes, yielded/returned results, and detection for when an
/// operation run begins and ends.
public struct MutationEventHandler<State: _MutationStateProtocol>: Sendable {
  /// A callback that is invoked when the mutation state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when a mutating has started.
  public var onMutatingStarted: (@Sendable (State.Arguments, OperationContext) -> Void)?

  /// A callback that is invoked when a mutating has ended.
  public var onMutatingEnded: (@Sendable (State.Arguments, OperationContext) -> Void)?

  /// A callback that is invoked when a mutation emits a result.
  public var onMutationResultReceived:
    (@Sendable (State.Arguments, Result<State.Value, State.Failure>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the mutation state changes.
  ///   - onMutatingStarted: A callback that is invoked when a mutating has started.
  ///   - onMutatingEnded: A callback that is invoked when a mutating has ended.
  ///   - onMutationResultReceived: A callback that is invoked when a mutation emits a result.
  public init(
    onStateChanged: (@Sendable (State, OperationContext) -> Void)? = nil,
    onMutatingStarted: (@Sendable (State.Arguments, OperationContext) -> Void)? = nil,
    onMutationResultReceived: (
      @Sendable (State.Arguments, Result<State.Value, State.Failure>, OperationContext) -> Void
    )? = nil,
    onMutatingEnded: (@Sendable (State.Arguments, OperationContext) -> Void)? = nil
  ) {
    self.onMutatingStarted = onMutatingStarted
    self.onMutationResultReceived = onMutationResultReceived
    self.onMutatingEnded = onMutatingEnded
    self.onStateChanged = onStateChanged
  }
}
