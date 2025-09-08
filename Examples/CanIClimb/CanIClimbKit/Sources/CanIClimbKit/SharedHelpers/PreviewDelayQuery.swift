import Dependencies
import Operation

extension OperationRequest {
  public func previewDelay(
    shouldDisable: Bool = false,
    _ delay: Duration? = nil
  ) -> ModifiedOperation<Self, _PreviewDelayModifier<Self>> {
    self.modifier(_PreviewDelayModifier(shouldDisable: shouldDisable, delay: delay))
  }
}

public struct _PreviewDelayModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let shouldDisable: Bool
  let delay: Duration?

  public func setup(context: inout OperationContext, using query: Operation) {
    context[DisablePreviewDelayKey.self] = self.shouldDisable
    query.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using query: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    @Dependency(\.context) var mode
    guard mode == .preview && !context[DisablePreviewDelayKey.self] else {
      return try await query.run(isolation: isolation, in: context, with: continuation)
    }
    if let delay {
      try? await Task.sleep(for: delay)
    } else {
      try? await Task.sleep(for: .seconds(Double.random(in: 0.1...3)))
    }
    return try await query.run(isolation: isolation, in: context, with: continuation)
  }
}

private enum DisablePreviewDelayKey: OperationContext.Key {
  static let defaultValue = false
}
