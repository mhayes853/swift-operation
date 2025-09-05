extension StatefulOperationRequest {
  public func handleEvents(
    with eventHandler: OperationEventHandler<State>
  ) -> ModifiedOperation<Self, _HandleEventsModifier<Self>> {
    self.modifier(_HandleEventsModifier(eventHandler: eventHandler))
  }
}

public struct _HandleEventsModifier<
  Operation: StatefulOperationRequest
>: OperationModifier, Sendable {
  let eventHandler: OperationEventHandler<Operation.State>

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    defer { self.eventHandler.onFetchingEnded?(context) }
    do {
      self.eventHandler.onFetchingStarted?(context)
      let value = try await operation.run(
        isolation: isolation,
        in: context,
        with: OperationContinuation { result, yieldedContext in
          var context = yieldedContext ?? context
          context.operationResultUpdateReason = .yieldedResult
          self.eventHandler.onResultReceived?(result, context)
          continuation.yield(with: result, using: context)
        }
      )

      var context = context
      context.operationResultUpdateReason = .returnedFinalResult
      self.eventHandler.onResultReceived?(.success(value), context)

      return value
    } catch {
      var context = context
      context.operationResultUpdateReason = .returnedFinalResult
      self.eventHandler.onResultReceived?(.failure(error), context)
      throw error
    }
  }
}
