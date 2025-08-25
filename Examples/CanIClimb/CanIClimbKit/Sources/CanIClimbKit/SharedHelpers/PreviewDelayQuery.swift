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

public struct _PreviewDelayModifier<Query: QueryRequest>: OperationModifier {
  let shouldDisable: Bool
  let delay: Duration?

  public func setup(context: inout OperationContext, using query: Query) {
    context[DisablePreviewDelayKey.self] = self.shouldDisable
    query.setup(context: &context)
  }

  public func fetch(
    in context: OperationContext,
    using query: Query,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    @Dependency(\.context) var mode
    guard mode == .preview && !context[DisablePreviewDelayKey.self] else {
      return try await query.fetch(in: context, with: continuation)
    }
    if let delay {
      try await Task.sleep(for: delay)
    } else {
      try await Task.sleep(for: .seconds(Double.random(in: 0.1...3)))
    }
    return try await query.fetch(in: context, with: continuation)
  }
}

private enum DisablePreviewDelayKey: OperationContext.Key {
  static let defaultValue = false
}
