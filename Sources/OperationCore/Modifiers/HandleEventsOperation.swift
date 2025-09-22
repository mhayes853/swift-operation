extension StatefulOperationRequest {
  /// Handles events from this operation using an ``OperationEventHandler``.
  ///
  /// Immediately after ``OperationRequest/run(isolation:in:with:)`` is invoked,
  /// ``OperationEventHandler/onRunStarted`` is invoked. Whenever this operation yields or returns
  /// its final result, ``OperationEventHandler/onResultReceived`` is invoked. After the final
  /// result has been returned from this operation, ``OperationEventHandler/onRunEnded`` is
  /// invoked.
  ///
  /// ``OperationEventHandler/onStateChanged`` is not invoked by this modifier, and is invoked by
  /// ``OperationStore`` instead.
  ///
  /// `OperationStore` automatically applies this modifier to your operation when a run begins.
  ///
  /// - Parameter eventHandler: An event handler.
  /// - Returns: A ``ModifiedOperation``.
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
    defer { self.eventHandler.onRunEnded?(context) }
    do {
      self.eventHandler.onRunStarted?(context)
      let onResultReceived = self.eventHandler.onResultReceived
      let value = try await operation.run(
        isolation: isolation,
        in: context,
        with: OperationContinuation { result, yieldedContext in
          var context = yieldedContext ?? context
          context.operationResultUpdateReason = .yieldedResult
          onResultReceived?(result, context)
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
