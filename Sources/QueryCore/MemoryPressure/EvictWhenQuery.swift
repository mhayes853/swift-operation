// MARK: - QueryRequest

extension QueryRequest {
  /// Indicates what severities that this query should be evicted from
  /// ``QueryClient/DefaultStoreCache`` upon receiving a memory pressure notification.
  ///
  /// You can use this modifier to ensure that certain queries are never evicted from the store
  /// cache, even if system memory runs low. For instance:
  ///
  /// ```swift
  /// // 🔵 Indicates that query should never be evicted from the store cache.
  /// let query = MyQuery().evictWhen(pressure: [])
  /// ```
  ///
  /// - Parameter pressure: The ``MemoryPressure`` at which this query should be evicted.
  /// - Returns: A ``ModifiedQuery``.
  public func evictWhen(
    pressure: MemoryPressure
  ) -> ModifiedQuery<Self, _EvictWhenPressureModifier<Self>> {
    self.modifier(_EvictWhenPressureModifier(pressure: pressure))
  }
}

public struct _EvictWhenPressureModifier<Query: QueryRequest>: QueryModifier {
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
  /// The required ``MemoryPressure`` severity to evict the ``QueryStore`` from
  /// ``QueryClient/DefaultStoreCache`` upon receiving a memory pressure notification.
  ///
  /// The default value is ``MemoryPressure/defaultEvictable``.
  public var evictableMemoryPressure: MemoryPressure {
    get { self[EvictableMemoryPressureKey.self] }
    set { self[EvictableMemoryPressureKey.self] = newValue }
  }

  private enum EvictableMemoryPressureKey: Key {
    static var defaultValue: MemoryPressure { .defaultEvictable }
  }
}
