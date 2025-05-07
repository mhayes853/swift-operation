import CustomDump
import Query
import Testing
import _TestQueries

@Suite("QueryClient+DefaultStoreCache tests")
struct QueryClientDefaultStoreCacheTests {
  private let source = TestMemoryPressureSource()
  private let client: QueryClient

  init() {
    let cache = QueryClient.DefaultStoreCache(memoryPressureSource: source)
    self.client = QueryClient(storeCache: cache)
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
}
