import Dependencies
import Query

// MARK: - Random Delay

extension QueryRequest {
  public func previewDelay(
    shouldDisable: Bool = false,
    _ delay: Duration? = nil
  ) -> ModifiedQuery<Self, _PreviewDelayModifier<Self>> {
    self.modifier(_PreviewDelayModifier(shouldDisable: shouldDisable, delay: delay))
  }
}

public struct _PreviewDelayModifier<Query: QueryRequest>: QueryModifier {
  let shouldDisable: Bool
  let delay: Duration?

  public func setup(context: inout QueryContext, using query: Query) {
    context[DisablePreviewDelayKey.self] = self.shouldDisable
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
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

private enum DisablePreviewDelayKey: QueryContext.Key {
  static let defaultValue = false
}

// MARK: - PreviewStoreCreator

extension QueryClient {
  public struct PreviewStoreCreator: StoreCreator {
    var base: any StoreCreator = .default()

    public func store<Query: QueryRequest>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State> {
      self.base.store(for: query.previewDelay(), in: context, with: initialState)
    }
  }
}

extension QueryClient.StoreCreator where Self == QueryClient.PreviewStoreCreator {
  public static var preview: Self {
    QueryClient.PreviewStoreCreator()
  }

  public static func preview(base: any QueryClient.StoreCreator) -> Self {
    QueryClient.PreviewStoreCreator(base: base)
  }
}
