@_spi(Warnings) import Operation

// MARK: - UnbackedOperation

struct UnbackedOperation<State: OperationState>: OperationRequest, Sendable {
  let path = OperationPath("__sharing_operation_unbacked_operation_\(typeName(State.self))__")

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<State.OperationValue>
  ) async throws -> State.OperationValue {
    reportWarning(.unbackedOperationFetch(type: State.self))
    throw UnbackedQueryError()
  }
}

private struct UnbackedQueryError: Error {}

// MARK: - Warning

extension OperationWarning {
  public static func unbackedOperationFetch(type: Any.Type) -> Self {
    """
    An unbacked shared operation attempted to fetch its data. Doing so has no effect on the value of \
    the operation.

        State Type: \(typeName(type))
    """
  }
}
