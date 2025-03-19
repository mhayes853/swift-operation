// MARK: - RetryModifier

extension QueryProtocol {
  public func retry(limit: Int) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(RetryModifier(limit: limit))
  }
}

private struct RetryModifier<Query: QueryProtocol>: QueryModifier {
  let limit: Int

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    var context = context
    for index in 0..<self.limit {
      do {
        context.retryIndex = index
        return try await query.fetch(in: context)
      } catch {
        continue
      }
    }
    context.retryIndex = self.limit
    return try await query.fetch(in: context)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var retryIndex: Int {
    get { self[RetryIndexKey.self] }
    set { self[RetryIndexKey.self] = newValue }
  }

  private enum RetryIndexKey: Key {
    static let defaultValue = 0
  }
}
