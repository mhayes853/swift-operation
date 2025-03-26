// MARK: - MutationEventHandler

public struct MutationEventHandler<Arguments: Sendable, Value: Sendable>: Sendable {
  public var onStateChanged: (@Sendable (MutationState<Arguments, Value>, QueryContext) -> Void)?
  public var onMutatingStarted: (@Sendable (Arguments, QueryContext) -> Void)?
  public var onMutationResultReceived:
    (@Sendable (Arguments, Result<Value, any Error>, QueryContext) -> Void)?
  public var onMutatingEnded: (@Sendable (Arguments, QueryContext) -> Void)?

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
