// MARK: - QueryRequest

extension OperationRequest {
  /// Indicates what severities that this query should be evicted from
  /// ``OperationClient/DefaultStoreCache`` upon receiving a memory pressure notification.
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
  /// - Returns: A ``ModifiedOperation``.
  public func evictWhen(
    pressure: MemoryPressure
  ) -> ModifiedOperation<Self, _EvictWhenPressureModifier<Self>> {
    self.modifier(_EvictWhenPressureModifier(pressure: pressure))
  }
}

public struct _EvictWhenPressureModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier {
  let pressure: MemoryPressure

  public func setup(context: inout OperationContext) {
    context.evictableMemoryPressure = self.pressure
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The required ``MemoryPressure`` severity to evict the ``OperationStore`` from
  /// ``OperationClient/DefaultStoreCache`` upon receiving a memory pressure notification.
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
