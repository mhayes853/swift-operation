import Foundation

// MARK: - InMemoryQueryCache

public struct InMemoryQueryCache<Value: Sendable> {
  private let cost: Int
  private let storage: InMemoryQueryCacheStorage?

  public init(cost: Int = 0, storage: InMemoryQueryCacheStorage? = nil) {
    self.cost = cost
    self.storage = storage
  }
}

extension InMemoryQueryCache: QueryCache {
  public func value(
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws -> QueryCacheValue<Value>? {
    let storage = self.cacheStorage(in: context)
    let key = InMemoryQueryCacheStorageKey(path: query.path)
    guard let value = storage.object(forKey: key)?.value as? Value else {
      return nil
    }
    return .stale(value)
  }

  public func save(
    _ value: Value,
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws {
    let storage = self.cacheStorage(in: context)
    let key = InMemoryQueryCacheStorageKey(path: query.path)
    let value = InMemoryQueryCacheStorageValue(value: value)
    storage.setObject(value, forKey: key, cost: self.cost)
  }

  public func removeValue(
    for query: some QueryProtocol<Value>,
    in context: QueryContext
  ) async throws {
    let storage = self.cacheStorage(in: context)
    storage.removeObject(forKey: InMemoryQueryCacheStorageKey(path: query.path))
  }

  private func cacheStorage(in context: QueryContext) -> InMemoryQueryCacheStorage {
    self.storage ?? context.defaultInMemoryQueryCacheStorage
  }
}

extension QueryCache {
  public static func inMemory<Value>(
    cost: Int = 0,
    storage: InMemoryQueryCacheStorage? = nil
  ) -> Self where Self == InMemoryQueryCache<Value> {
    InMemoryQueryCache(cost: cost, storage: storage)
  }
}

// MARK: - QueryPathCacheKey

@objc public final class InMemoryQueryCacheStorageKey: NSObject, Sendable {
  private let path: QueryPath

  fileprivate init(path: QueryPath) {
    self.path = path
  }
}

extension InMemoryQueryCacheStorageKey {
  public override var hash: Int {
    path.hashValue
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let value = object as? InMemoryQueryCacheStorageKey else {
      return false
    }
    return value.path == self.path
  }
}

// MARK: - InMemoryValue

@objc public final class InMemoryQueryCacheStorageValue: NSObject, Sendable {
  public let value: any Sendable

  fileprivate init(value: any Sendable) {
    self.value = value
  }
}

// MARK: - NSCache

public typealias InMemoryQueryCacheStorage = NSCache<
  InMemoryQueryCacheStorageKey, InMemoryQueryCacheStorageValue
>

extension QueryContext {
  public var defaultInMemoryQueryCacheStorage: InMemoryQueryCacheStorage {
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
