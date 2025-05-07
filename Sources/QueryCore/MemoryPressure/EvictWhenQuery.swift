// MARK: - QueryRequest

extension QueryRequest {
  public func evictWhen(
    pressure: MemoryPressure
  ) -> ModifiedQuery<Self, EvictWhenPressureModifier<Self>> {
    self.modifier(EvictWhenPressureModifier(pressure: pressure))
  }
}

public struct EvictWhenPressureModifier<Query: QueryRequest>: QueryModifier {
  let pressure: MemoryPressure

  public func setup(context: inout QueryContext, using query: Query) {
    context.evictableMemoryPressure = self.pressure
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }

}

// MARK: - QueryContext

extension QueryContext {
  public var evictableMemoryPressure: MemoryPressure {
    get { self[EvictableMemoryPressureKey.self] }
    set { self[EvictableMemoryPressureKey.self] = newValue }
  }

  private enum EvictableMemoryPressureKey: Key {
    static var defaultValue: MemoryPressure { .defaultEvictable }
  }
}
