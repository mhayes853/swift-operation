// MARK: - StoreCache

extension QueryClient {
  public protocol StoreCache: Sendable {
    func withStores<T>(_ fn: (inout sending [QueryPath: OpaqueQueryStore]) -> sending T) -> T
  }
}

// MARK: - DefaultStoreCache

extension QueryClient {
  public final class DefaultStoreCache: StoreCache {
    private let stores = Lock([QueryPath: OpaqueQueryStore]())

    public init(memoryPressureSource: (any MemoryPressureSource)? = defaultMemoryPressureSource) {
    }

    public func withStores<T>(
      _ fn: (inout sending [QueryPath: OpaqueQueryStore]) -> sending T
    ) -> T {
      self.stores.withLock(fn)
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
