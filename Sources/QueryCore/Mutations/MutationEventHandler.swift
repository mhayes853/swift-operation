// MARK: - MutationEventHandler

public struct MutationEventHandler<Arguments: Sendable, Value: Sendable>: Sendable {
  let onMutatingStarted: (@Sendable (Arguments) -> Void)?
  let onMutationResultReceived: (@Sendable (Arguments, Result<Value, any Error>) -> Void)?
  let onMutatingEnded: (@Sendable (Arguments) -> Void)?

  public init(
    onMutatingStarted: (@Sendable (Arguments) -> Void)? = nil,
    onMutationResultReceived: (@Sendable (Arguments, Result<Value, any Error>) -> Void)? = nil,
    onMutatingEnded: (@Sendable (Arguments) -> Void)? = nil
  ) {
    self.onMutatingStarted = onMutatingStarted
    self.onMutationResultReceived = onMutationResultReceived
    self.onMutatingEnded = onMutatingEnded
  }
}
