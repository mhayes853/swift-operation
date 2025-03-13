import Foundation

// MARK: - InMemoryQueryCache

public struct InMemoryQueryCache<Value: Sendable> {
  let cost: Int
  let cache: InMemoryQueryCacheStorage?
}

extension InMemoryQueryCache: QueryCache {
  public func value(
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws -> QueryCacheValue<Value>? {
    nil
  }

  public func saveValue(
    _ value: Value,
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws {

  }

  public func removeValue(
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws {

  }

}

extension QueryCache {
  public static func inMemory<Value>(
    cost: Int = 0,
    cache: InMemoryQueryCacheStorage? = nil
  ) -> Self where Self == InMemoryQueryCache<Value> {
    InMemoryQueryCache(cost: cost, cache: cache)
  }
}

// MARK: - QueryPathCacheKey

public final class InMemoryQueryCacheKey: Sendable {
  private let path: QueryPath

  fileprivate init(path: QueryPath) {
    self.path = path
  }
}

// MARK: - InMemoryValue

public final class InMemoryQueryCacheValue: Sendable {
  fileprivate let value: any Sendable

  fileprivate init(value: any Sendable) {
    self.value = value
  }
}

// MARK: - NSCache

public typealias InMemoryQueryCacheStorage = NSCache<InMemoryQueryCacheKey, InMemoryQueryCacheValue>

extension QueryContext {
  public var defaultInMemoryCacheStorage: InMemoryQueryCacheStorage {
    get { self[DefaultInMemoryCacheStorageKey.self].inner }
    set { self[DefaultInMemoryCacheStorageKey.self] = CacheStorage(inner: newValue) }
  }

  private enum DefaultInMemoryCacheStorageKey: Key {
    static var defaultValue: CacheStorage { .shared }
  }
}

private struct CacheStorage: @unchecked Sendable {
  let inner: InMemoryQueryCacheStorage
}

extension CacheStorage {
  static let shared = CacheStorage(inner: InMemoryQueryCacheStorage())
}
