// MARK: - StoreCache

extension QueryClient {
  public protocol StoreCache: Sendable {
    func withStores<T>(_ fn: (inout sending [QueryPath: OpaqueQueryStore]) -> sending T) -> T
  }
}

// MARK: - DefaultStoreCache

extension QueryClient {
  public final class DefaultStoreCache: StoreCache {
    private let stores: LockedBox<[QueryPath: OpaqueQueryStore]>
    private let subscription: QuerySubscription

    public init(memoryPressureSource: (any MemoryPressureSource)? = defaultMemoryPressureSource) {
      let box = LockedBox(value: [QueryPath: OpaqueQueryStore]())
      self.stores = box
      let subscription = memoryPressureSource?
        .subscribe { pressure in
          box.inner.withLock { stores in
            for (path, store) in stores {
              guard
                store.subscriberCount == 0
                  && store.context.evictableMemoryPressure.contains(pressure)
              else { continue }
              stores.removeValue(forKey: path)
            }
          }
        }
      self.subscription = subscription ?? .empty
    }

    public func withStores<T>(
      _ fn: (inout sending [QueryPath: OpaqueQueryStore]) -> sending T
    ) -> T {
      self.stores.inner.withLock(fn)
    }
  }
}

// MARK: - Default Memory Pressure Source

public var defaultMemoryPressureSource: (any MemoryPressureSource)? {
  #if canImport(Dispatch)
    .dispatch
  #else
    nil
  #endif
}
