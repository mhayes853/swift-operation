// MARK: - MutationEventHandler

public struct MutationEventHandler<Arguments: Sendable, Value: Sendable>: Sendable {
  let onMutatingStarted: (@Sendable (Arguments, QueryContext) -> Void)?
  let onMutationResultReceived:
    (@Sendable (Arguments, Result<Value, any Error>, QueryContext) -> Void)?
  let onMutatingEnded: (@Sendable (Arguments, QueryContext) -> Void)?
  let onStateChanged: (@Sendable (MutationState<Arguments, Value>, QueryContext) -> Void)?

  public init(
    onMutatingStarted: (@Sendable (Arguments, QueryContext) -> Void)? = nil,
    onMutationResultReceived: (
      @Sendable (Arguments, Result<Value, any Error>, QueryContext) -> Void
    )? = nil,
    onMutatingEnded: (@Sendable (Arguments, QueryContext) -> Void)? = nil,
    onStateChanged: (@Sendable (MutationState<Arguments, Value>, QueryContext) -> Void)? = nil
  ) {
    self.onMutatingStarted = onMutatingStarted
    self.onMutationResultReceived = onMutationResultReceived
    self.onMutatingEnded = onMutatingEnded
    self.onStateChanged = onStateChanged
  }
}
