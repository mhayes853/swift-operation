import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("OperationClient+DefaultStoreCache tests")
struct DefaultStoreCacheTests {
  private let source = TestMemoryPressureSource()
  private var storeCache: OperationClient.DefaultStoreCache
  private let client: OperationClient

  init() {
    let cache = OperationClient.DefaultStoreCache(memoryPressureSource: source)
    self.storeCache = cache
    self.client = OperationClient(storeCache: cache)
  }

  @Test("Does Not Evict When Normal Pressure Emitted")
  func doesNotEvictWhenNormalPressureEmitted() {
    let store = self.client.store(for: TestQuery())
    self.source.send(pressure: .normal)
    expectNoDifference(self.client.stores(matching: store.path).count, 1)
  }

  @Test("Evicts When Warning Pressure Emitted")
  func evictsWhenWarningPressureEmitted() {
    let store = self.client.store(for: TestQuery())
    self.source.send(pressure: .warning)
    expectNoDifference(self.client.stores(matching: store.path).count, 0)
  }

  @Test("Evicts When Critical Pressure Emitted")
  func evictsWhenCriticalPressureEmitted() {
    let store = self.client.store(for: TestQuery())
    self.source.send(pressure: .critical)
    expectNoDifference(self.client.stores(matching: store.path).count, 0)
  }

  @Test("Does Not Evict Queries That Have Subscribers")
  func doesNotEvictQueriesThatHaveSubscribers() {
    let store = self.client.store(for: TestQuery())
    let subscription = store.subscribe(with: QueryEventHandler())
    self.source.send(pressure: .critical)
    expectNoDifference(self.client.stores(matching: store.path).count, 1)
    subscription.cancel()
  }

  @Test("Does Not Evict Non-Evictable Queries")
  func doesNotEvictQueriesThatAreNonEvictable() {
    let store = self.client.store(for: TestQuery().evictWhen(pressure: []))
    self.source.send(pressure: .critical)
    expectNoDifference(self.client.stores(matching: store.path).count, 1)
  }

  @Test("Recognizes Store Retroactively Added To Cache")
  mutating func recognizesStoreRetroactivelyAddedToCache() {
    let store = OperationStore.detached(query: TestQuery(), initialValue: nil)
    self.storeCache.withStores { $0.update(OpaqueOperationStore(erasing: store)) }
    let clientStore = self.client.store(for: TestQuery())
    expectNoDifference(store === clientStore, true)
  }
}
