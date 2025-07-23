import Foundation

// MARK: - StoreCache

extension QueryClient {
  /// A protocol for managing the in-memory storage of ``QueryStore`` instances that a
  /// ``QueryClient`` holds.
  public protocol StoreCache {
    /// Provides scoped access to the stores in this cache.
    ///
    /// - Parameter body: A function that runs with scoped access to the stores.
    /// - Returns: Whatever `body` returns.
    mutating func withStores<T>(
      _ body: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
    ) rethrows -> sending T
  }
}

extension QueryClient.StoreCache {
  func stores() -> QueryPathableCollection<OpaqueQueryStore> {
    var current = self
    return current.withStores { $0 }
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
  public final class DefaultStoreCache: @unchecked Sendable {
    private struct State {
      var stores = QueryPathableCollection<OpaqueQueryStore>()
      var subscription = QuerySubscription.empty
    }
    private let state = Lock(State())

    /// Creates a default store cache.
    ///
    /// - Parameter memoryPressureSource: The ``MemoryPressureSource`` to use to detect when the
    ///   system is running low on memory. If nil is provided, then the cache will not listen for
    ///   low memory warnings, and will therefore never evict any inactive stores.
    public init(
      memoryPressureSource: sending (any MemoryPressureSource)? = defaultMemoryPressureSource
    ) {
      self.state.withLock { state in
        let subscription = memoryPressureSource?
          .subscribe { [weak self] pressure in
            self?.withStores { stores in stores.removeAll { $0.isEvictable(from: pressure) } }
          }
        state.subscription = subscription ?? .empty
      }
    }
  }
}

extension QueryClient.DefaultStoreCache: QueryClient.StoreCache {
  public func withStores<T>(
    _ body: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
  ) rethrows -> sending T {
    try self.state.withLock { try body(&$0.stores) }
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
