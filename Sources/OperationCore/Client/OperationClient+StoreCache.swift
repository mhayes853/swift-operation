import Foundation

// MARK: - StoreCache

extension OperationClient {
  /// A protocol for managing the in-memory storage of ``OperationStore`` instances that a
  /// ``OperationClient`` holds.
  public protocol StoreCache {
    /// Provides scoped access to the stores in this cache.
    ///
    /// - Parameter body: A function that runs with scoped access to the stores.
    /// - Returns: Whatever `body` returns.
    mutating func withStores<T>(
      _ body: (inout sending OperationPathableCollection<OpaqueOperationStore>) throws -> sending T
    ) rethrows -> sending T
  }
}

extension OperationClient.StoreCache {
  func stores() -> OperationPathableCollection<OpaqueOperationStore> {
    var current = self
    return current.withStores { $0 }
  }
}

// MARK: - DefaultStoreCache

extension OperationClient {
  /// A default conformance of the ``StoreCache`` protocol.
  ///
  /// This conformance will evict stores from memory when the system runs low on memory if a
  /// ``MemoryPressureSource`` is provided in the initializer. If no pressure source is provided,
  /// then all created stores will remain in-memory for the lifetime of the application unless
  /// explicity cleared through the ``OperationClient``.
  ///
  /// Only stores that have no active subscribers are evicted from the cache, and you can customize
  /// the ``MemoryPressure`` value at which a store is evicted via the
  /// ``QueryRequest/evictWhen(pressure:)`` modifier.
  public final class DefaultStoreCache: OperationClient.StoreCache, Sendable {
    private struct State {
      var stores = OperationPathableCollection<OpaqueOperationStore>()
      var subscription = OperationSubscription.empty
    }

    private let state = RecursiveLock(State())

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

    public func withStores<T>(
      _ body: (inout sending OperationPathableCollection<OpaqueOperationStore>) throws -> sending T
    ) rethrows -> sending T {
      try self.state.withLock { try body(&$0.stores) }
    }
  }
}

extension OpaqueOperationStore {
  fileprivate func isEvictable(from pressure: MemoryPressure) -> Bool {
    self.withExclusiveAccess {
      $0.subscriberCount == 0 && $0.context.evictableMemoryPressure.contains(pressure)
    }
  }
}

// MARK: - Default Memory Pressure Source

extension OperationClient {
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
