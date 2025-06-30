// MARK: - StoreCache

extension QueryClient {
  /// A protocol for managing the in-memory storage of ``QueryStore`` instances that a
  /// ``QueryClient`` holds.
  ///
  /// Conformances to this protocol must be thread-safe in order to uphold `QueryClient`
  /// sendability guarantees.
  public protocol StoreCache: Sendable {
    /// Provides scoped, exclusive, and mutable access to the stores managed by the ``QueryClient``.
    ///
    /// - Parameter fn: A function to edit the underlying collection of query stores.
    /// - Returns: Whatever `fn` returns.
    func withLock<T>(
      _ fn: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
    ) rethrows -> T
  }
}

// MARK: - DefaultStoreCache

extension QueryClient {
  /// A default conformance of the ``StoreCache`` protocol.
  ///
  /// This conformance will evict stores from memory when the system runs low on memory if a
  /// ``MemoryPressureSource`` is provided in the initializer. If no pressure source is provided,
  /// then all created stores will remain in-memory for the lifetime of the application unless
  /// explicity cleared through the ``QueryClient``.
  ///
  /// Only stores that have no active subscribers are evicted from the cache, and you can customize
  /// the ``MemoryPressure`` value at which a store is evicted via the
  /// ``QueryRequest/evictWhen(pressure:)`` modifier.
  public final class DefaultStoreCache: StoreCache {
    private let stores: LockedBox<QueryPathableCollection<OpaqueQueryStore>>
    private let subscription: QuerySubscription
    
    /// Creates a default store cache.
    ///
    /// - Parameter memoryPressureSource: The ``MemoryPressureSource`` to use to detect when the
    ///   system is running low on memory. If nil is provided, then the cache will not listen for
    ///   low memory warnings, and will therefore never evict any inactive stores.
    public init(memoryPressureSource: (any MemoryPressureSource)? = defaultMemoryPressureSource) {
      let box = LockedBox(value: QueryPathableCollection<OpaqueQueryStore>())
      self.stores = box
      let subscription = memoryPressureSource?
        .subscribe { pressure in
          box.inner.withLock { stores in
            stores.removeAll { $0.isEvictable(from: pressure) }
          }
        }
      self.subscription = subscription ?? .empty
    }

    public func withLock<T>(
      _ fn: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
    ) rethrows -> T {
      try self.stores.inner.withLock(fn)
    }
  }
}

extension OpaqueQueryStore {
  fileprivate func isEvictable(from pressure: MemoryPressure) -> Bool {
    self.withExclusiveAccess {
      self.subscriberCount == 0 && self.context.evictableMemoryPressure.contains(pressure)
    }
  }
}

// MARK: - Default Memory Pressure Source

extension QueryClient {
  /// The default ``MemoryPressureSource`` for the current platform.
  ///
  /// - On Apple platforms, this defaults to ``DispatchMemoryPressureSource``.
  /// - On all other platforms, this value is nil.
  public static var defaultMemoryPressureSource: (any MemoryPressureSource)? {
    #if canImport(Darwin)
      .dispatch
    #else
      nil
    #endif
  }
}
