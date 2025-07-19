/// An event handler that's passed to ``QueryStore/subscribe(with:)-7si49``.
public struct MutationEventHandler<Arguments: Sendable, Value: Sendable>: Sendable {
  /// A callback that is invoked when the mutation state changes.
  public var onStateChanged: (@Sendable (MutationState<Arguments, Value>, QueryContext) -> Void)?

  /// A callback that is invoked when a mutation is started on the ``QueryStore``.
  public var onMutatingStarted: (@Sendable (Arguments, QueryContext) -> Void)?

  /// A callback that is invoked when a mutation ends on the ``QueryStore``.
  public var onMutatingEnded: (@Sendable (Arguments, QueryContext) -> Void)?

  /// A callback that is invoked when a mutation emits a result.
  public var onMutationResultReceived:
    (@Sendable (Arguments, Result<Value, any Error>, QueryContext) -> Void)?

  /// Creates an event handler.
  ///
  /// - Parameters:
  ///   - onStateChanged: A callback that is invoked when the mutation state changes.
  ///   - onMutatingStarted: A callback that is invoked when a mutation is started on the ``QueryStore``.
  ///   - onMutationResultReceived: A callback that is invoked when a mutation emits a result.
  ///   - onMutatingEnded: A callback that is invoked when a mutation ends on the ``QueryStore``.
  public init(
    onStateChanged: (@Sendable (MutationState<Arguments, Value>, QueryContext) -> Void)? = nil,
    onMutatingStarted: (@Sendable (Arguments, QueryContext) -> Void)? = nil,
    onMutationResultReceived: (
      @Sendable (Arguments, Result<Value, any Error>, QueryContext) -> Void
    )? = nil,
    onMutatingEnded: (@Sendable (Arguments, QueryContext) -> Void)? = nil
  ) {
    self.onMutatingStarted = onMutatingStarted
    self.onMutationResultReceived = onMutationResultReceived
    self.onMutatingEnded = onMutatingEnded
    self.onStateChanged = onStateChanged
  }
}
