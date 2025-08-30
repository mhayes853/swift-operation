/// An event handler that's passed to ``OperationStore/subscribe(with:)-7si49``.
public struct MutationEventHandler<State: _MutationStateProtocol>: Sendable {
  /// A callback that is invoked when the mutation state changes.
  public var onStateChanged: (@Sendable (State, OperationContext) -> Void)?

  /// A callback that is invoked when a mutation is started on the ``OperationStore``.
  public var onMutatingStarted: (@Sendable (State.Arguments, OperationContext) -> Void)?

  /// A callback that is invoked when a mutation ends on the ``OperationStore``.
  public var onMutatingEnded: (@Sendable (State.Arguments, OperationContext) -> Void)?

  /// A callback that is invoked when a mutation emits a result.
  public var onMutationResultReceived:
    (@Sendable (State.Arguments, Result<State.Value, State.Failure>, OperationContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the mutation state changes.
  ///   - onMutatingStarted: A callback that is invoked when a mutation is started on the ``OperationStore``.
  ///   - onMutationResultReceived: A callback that is invoked when a mutation emits a result.
  ///   - onMutatingEnded: A callback that is invoked when a mutation ends on the ``OperationStore``.
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
