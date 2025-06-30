// MARK: - StoreCache

extension QueryClient {
  public protocol StoreCache: Sendable {
    func withLock<T>(
      _ fn: (inout sending QueryPathableCollection<OpaqueQueryStore>) throws -> sending T
    ) rethrows -> T
  }
}

// MARK: - DefaultStoreCache

extension QueryClient {
  public final class DefaultStoreCache: StoreCache {
    private let stores: LockedBox<QueryPathableCollection<OpaqueQueryStore>>
    private let subscription: QuerySubscription

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
  public static var defaultMemoryPressureSource: (any MemoryPressureSource)? {
    #if canImport(Darwin)
      .dispatch
    #else
      nil
    #endif
  }
}
