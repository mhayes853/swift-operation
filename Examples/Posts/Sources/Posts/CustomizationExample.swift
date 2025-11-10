import Operation

extension OperationRequest {
  func delay(for duration: OperationDuration) -> ModifiedOperation<Self, DelayModifer<Self>> {
    self.modifier(DelayModifer(duration: duration))
  }
}

struct DelayModifer<Operation: OperationRequest>: OperationModifier, Sendable {
  let duration: OperationDuration

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    try? await context.operationDelayer.delay(for: self.duration)
    return try await operation.run(isolation: isolation, in: context, with: continuation)
  }
}

@QueryRequest
func someQuery() {
  // ...
}

@MutationRequest
func someMutation() {
  // ...
}

let delayedQuery = $someQuery.delay(for: .seconds(1))
let delayedMutation = $someMutation.delay(for: .seconds(1))
