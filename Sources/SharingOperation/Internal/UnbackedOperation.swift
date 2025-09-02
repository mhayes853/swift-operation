import Operation

struct UnbackedOperation<State: OperationState>: StatefulOperationRequest, Sendable {
  let path = OperationPath("__sharing_operation_unbacked_operation_\(typeName(State.self))__")

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<State.OperationValue, State.Failure>
  ) async throws(State.Failure) -> sending State.OperationValue {
    fatalError(_unbackedOperationRunError(stateType: State.self))
  }
}

package func _unbackedOperationRunError(stateType: Any.Type) -> String {
  """
  An unbacked shared operation attempted to fetch its data. This is not allowed because no \
  `OperationRequest` was provided to `@SharedOperation`.

      State Type: \(typeName(stateType))
  """
}
