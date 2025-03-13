import CustomDump
import QueryCore
import Testing

@Suite("InMemoryQueryCache tests")
struct InMemoryQueryCacheTests {
  private var context = QueryContext()
  private let testStorage = TestCacheStorage()

  init() {
    self.context.defaultInMemoryQueryCacheStorage = self.testStorage
  }

  @Test("Retrieve Empty Value Returns Nil")
  func retrieveEmptyValueReturnsNil() async throws {
    let cache = InMemoryQueryCache<TestQuery.Value>()
    let value = try await cache.value(for: TestQuery(), in: self.context)
    expectNoDifference(value, nil)
  }

  @Test("Save And Retrieve, Returns Stale Value")
  func saveAndRetrieveReturnsStaleValue() async throws {
    let cache = InMemoryQueryCache<TestQuery.Value>()

    try await cache.save(10, for: TestQuery(), in: self.context)
    let value = try await cache.value(for: TestQuery(), in: self.context)
    expectNoDifference(value, .stale(10))
  }

  @Test("Save, Remove, And Retrieve, Returns Nil")
  func saveRemoveAndRetrieveReturnsNil() async throws {
    let cache = InMemoryQueryCache<TestQuery.Value>()

    try await cache.save(10, for: TestQuery(), in: self.context)
    try await cache.removeValue(for: TestQuery(), in: self.context)
    let value = try await cache.value(for: TestQuery(), in: self.context)
    expectNoDifference(value, nil)
  }

  @Test("Overwrites Existing Value")
  func overwritesExistingValue() async throws {
    let cache = InMemoryQueryCache<TestQuery.Value>()

    try await cache.save(10, for: TestQuery(), in: self.context)
    try await cache.save(20, for: TestQuery(), in: self.context)
    let value = try await cache.value(for: TestQuery(), in: self.context)
    expectNoDifference(value, .stale(20))
  }

  @Test("Stores Multiple Values For Different Keys")
  func storesMultipleValuesForDifferentKeys() async throws {
    let cache = InMemoryQueryCache<TestQuery.Value>()
    let cache2 = InMemoryQueryCache<TestStringQuery.Value>()

    try await cache.save(10, for: TestQuery(), in: self.context)
    try await cache2.save("blob", for: TestStringQuery(), in: self.context)
    let value1 = try await cache.value(for: TestQuery(), in: self.context)
    let value2 = try await cache2.value(for: TestStringQuery(), in: self.context)
    expectNoDifference(value1, .stale(10))
    expectNoDifference(value2, .stale("blob"))
  }

  @Test("Allows Cache Storage Override In Initializer")
  func allowsCacheStorageOverrideInInitializer() async throws {
    let storage = TestCacheStorage()
    let cache = InMemoryQueryCache<TestQuery.Value>(storage: storage)

    try await cache.save(10, for: TestQuery(), in: self.context)
    storage.state.withLock { expectNoDifference($0.isEmpty, false) }
    self.testStorage.state.withLock { expectNoDifference($0.isEmpty, true) }
  }

  @Test("Stores Custom Cost For Key")
  func storesCustomCostForKey() async throws {
    let cache = InMemoryQueryCache<TestQuery.Value>(cost: 100)

    try await cache.save(10, for: TestQuery(), in: self.context)
    self.testStorage.state.withLock { expectNoDifference($0.first!.value.cost, 100) }
  }
}

private final class TestCacheStorage: InMemoryQueryCacheStorage {
  typealias State = (cost: Int, value: InMemoryQueryCacheStorageValue)
  let state = Lock([InMemoryQueryCacheStorageKey: State]())
}

extension TestCacheStorage {
  override func setObject(
    _ obj: InMemoryQueryCacheStorageValue,
    forKey key: InMemoryQueryCacheStorageKey,
    cost g: Int
  ) {
    super.setObject(obj, forKey: key, cost: g)
    self.state.withLock { $0[key] = (cost: g, value: obj) }
  }

  override func removeObject(forKey key: InMemoryQueryCacheStorageKey) {
    super.removeObject(forKey: key)
    _ = self.state.withLock { $0.removeValue(forKey: key) }
  }
}
