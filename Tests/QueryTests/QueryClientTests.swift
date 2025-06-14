import CustomDump
import IssueReporting
@_spi(Warnings) import Query
import QueryTestHelpers
import Testing

@Suite("QueryClient tests")
struct QueryClientTests {
  @Test("Maintains The Same Query State For Multiple Stores With The Same Query")
  func maintainsValueForMultipleStores() async throws {
    let client = QueryClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1.currentValue, store2.currentValue)
    expectNoDifference(store2.currentValue, TestQuery.value)
  }

  @Test("Returns Same Store Reference For Same Query")
  func returnsSameStoreReferenceForSameQuery() async throws {
    let client = QueryClient()
    let store1 = client.store(for: TestQuery())
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1 === store2, true)
  }

  @Test("Reports Issue When Different Query Type Has The Same Path As Another Query")
  func cannotHaveDuplicatePaths() async throws {
    let client = QueryClient()
    _ = client.store(for: TestQuery())
    withKnownIssue {
      _ = client.store(for: TestQuery().defaultValue(TestQuery.value + 10))
    } matching: {
      $0.comments.contains(
        .warning(
          .duplicatePath(expectedType: TestQuery.self, foundType: DefaultQuery<TestQuery>.self)
        )
      )
    }
  }

  @Test("Does Not Crash When Duplicate Query Paths")
  func duplicatePathsCrashPrevention() async throws {
    let client = QueryClient()
    _ = client.store(for: TestQuery())
    withExpectedIssue {
      let store = client.store(for: TestQuery().defaultValue(TestQuery.value + 10))
      _ = store.currentValue
    }
  }

  @Test("Does Not Share States Between Different Queries")
  func doesNotShareStateBetweenDifferentQueries() async throws {
    let client = QueryClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestStringQuery().defaultValue("bar"))

    expectNoDifference(store1.currentValue, TestQuery.value)
    expectNoDifference(store2.currentValue, "bar")
  }

  @Test("Loads Queries Matching Path Prefix")
  func matchesPathPrefix() async throws {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2])
    let q2 = PathableQuery(value: 2, path: ["blob", "tlob"])
    let q3 = PathableQuery(value: 3, path: [1, "blobby"])
    _ = client.store(for: q1)
    let store1 = client.store(for: q2)
    let store2 = client.store(for: q3)
    _ = try await (store1.fetch(), store2.fetch())

    let stores = client.stores(matching: [1])
    try #require(stores.count == 2)

    expectNoDifference(stores[q1.path]?.currentValue as? Int, nil)
    expectNoDifference(stores[q3.path]?.currentValue as? Int, 3)

    try await stores[q1.path]?.fetch()
    expectNoDifference(stores[q1.path]?.currentValue as? Int, 1)
  }

  @Test("Clears Queries That Match The Specified Path")
  func clearQueriesMatchingPath() async throws {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.clearStores(matching: [1])

    let stores = client.stores(matching: [])
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores[q3.path] != nil, true)
  }

  @Test("Clears Queries That Equal The Specified Path")
  func clearQueryWithPath() {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.clearStore(with: [1, 2])

    let stores = client.stores(matching: [])
    expectNoDifference(stores.count, 2)
    expectNoDifference(stores[q3.path] != nil, true)
    expectNoDifference(stores[q2.path] != nil, true)
    expectNoDifference(stores[q1.path] == nil, true)
  }

  @Test("Only Retrieves Stores Of Specified State Type When Pattern Matching")
  func onlyRetrievesStoresOfSpecifiedStateTypeWhenPatternMatching() {
    let client = QueryClient()
    let q1 = TaggedPathableQuery<Int>(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery<Int>(value: 2, path: [2, 3])
    let q3 = TaggedPathableQuery<String>(value: "foo", path: [1, 4])
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    let stores = client.stores(matching: [1], of: TaggedPathableQuery<Int>.State.self)
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores[q1.path] != nil, true)
    expectNoDifference(stores[q2.path] == nil, true)
    expectNoDifference(stores[q3.path] == nil, true)
  }

  @Test("Sets Value For Store Through Path")
  func setValueForStoreThroughPath() async throws {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let store = client.store(for: q1)
    let opaqueStore = try #require(client.stores(matching: []).first)

    opaqueStore.uncheckedSetCurrentValue(20)
    expectNoDifference(store.currentValue, 20)
  }

  @Test("Sets Result For Store Through Path")
  func setResultForStoreThroughPath() async throws {
    struct SomeError: Equatable, Error {}

    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let store = client.store(for: q1)
    let opaqueStore = try #require(client.stores(matching: []).first)

    opaqueStore.uncheckedSetResult(to: .success(20))
    expectNoDifference(store.currentValue, 20)

    opaqueStore.uncheckedSetResult(to: .failure(SomeError()))
    expectNoDifference(store.error as? SomeError, SomeError())
  }

  @Test("Uses Default Value For AnyQueryStore")
  func defaultAnyQueryStoreValue() async throws {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    _ = client.store(for: q1)

    let stores = client.stores(matching: [])
    try #require(stores.count == 1)

    expectNoDifference(stores[q1.path]?.currentValue as? Int, 10)
    expectNoDifference(stores[q1.path]?.initialValue as? Int, 10)
  }

  @Test("Adds Current QueryClient Instance To The QueryContext")
  func queryClientInContext() async throws {
    let client = QueryClient()
    let query = ContextReadingQuery()
    let store = client.store(for: query)
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.queryClient)
    expectNoDifference(client === contextClient, true)
  }

  @Test("Sets Custom QueryClient Instance To The QueryContext")
  func setCustomQueryClientInContext() async throws {
    let client = QueryClient()
    let query = ContextReadingQuery()
    let store = QueryStore.detached(query: query, initialValue: nil)
    store.context.queryClient = client
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.queryClient)
    expectNoDifference(client === contextClient, true)
  }

  @Test("Loads AnyStore In A Loading State")
  func loadAnyStoreInLoadingState() async throws {
    let client = QueryClient()
    let query = SleepingQuery()
    let store = client.store(for: query)
    query.didBeginSleeping = {
      let anyStore = client.store(with: query.path)
      expectNoDifference(anyStore?.isLoading, true)
      query.resume()
    }
    try await store.fetch()
  }

  @Test("No AnyStore For QueryPath That Does Not Exist")
  func noAnyStoreForQueryPathThatDoesNotExist() async throws {
    let client = QueryClient()
    let store = client.store(with: [1, 2, 3])
    expectNoDifference(store == nil, true)
  }

  @Test("Only Subscribes To QueryController Once Per Store")
  func onlySubscribesToQueryControllerOncePerStore() async throws {
    let client = QueryClient()
    let controller = CountingController<TestQuery.State>()
    let query = TestQuery().controlled(by: controller)
    let store = client.store(for: query)
    _ = client.store(for: query)
    controller.count.withLock { expectNoDifference($0, 1) }
    _ = store
  }

  @Test("Resets Query State From Store Through Path")
  func resetQueryStateFromStoreThroughPath() async throws {
    let client = QueryClient()
    let query = PathableQuery(value: 10, path: [1, 2])
    let store = client.store(for: query)
    try await store.fetch()

    let opaqueStore = try #require(client.stores(matching: [1]).first)
    expectNoDifference(store.currentValue, 10)
    opaqueStore.resetState()
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Mutate OpaqueStore Entries")
  func mutateOpaqueStoreEntries() {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    let q4 = PathableQuery(value: 3, path: [2, 5]).defaultValue(40)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.withStores(matching: [1]) { entries in
      expectNoDifference(entries.count, 2)
      entries[q1.path]?.uncheckedSetCurrentValue(50)
      entries.update(OpaqueQueryStore(erasing: .detached(query: q4)))
      entries.removeValue(forPath: q2.path)
    }

    expectNoDifference(client.stores(matching: []).count, 3)
    expectNoDifference(client.store(for: q1).currentValue, 50)
    expectNoDifference(client.store(with: q2.path) == nil, true)
    expectNoDifference(client.store(for: q4).currentValue, 40)
  }

  @Test("Mutate Store Entries")
  func mutateStoreEntries() {
    let client = QueryClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = TaggedPathableQuery(value: "blob", path: [1, 4]).defaultValue("blob")
    let q4 = TaggedPathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    let q5 = TaggedPathableQuery(value: 3, path: [2, 5]).defaultValue(40)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)
    _ = client.store(for: q4)

    client.withStores(
      matching: [1],
      of: DefaultQuery<TaggedPathableQuery<Int>>.State.self
    ) { entries in
      expectNoDifference(entries.count, 2)
      entries[q1.path]?.currentValue = 50
      entries.update(.detached(query: q5))
      entries.removeValue(forPath: q2.path)
    }

    expectNoDifference(client.stores(matching: []).count, 4)
    expectNoDifference(client.store(for: q1).currentValue, 50)
    expectNoDifference(client.store(with: q2.path) == nil, true)
    expectNoDifference(client.store(for: q5).currentValue, 40)
  }

  @Suite("QueryClient+DefaultStoreCache tests")
  struct DefaultStoreCacheTests {
    private let source = TestMemoryPressureSource()
    private let storeCache: any QueryClient.StoreCache
    private let client: QueryClient

    init() {
      let cache = QueryClient.DefaultStoreCache(memoryPressureSource: source)
      self.storeCache = cache
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

    @Test("Does Not Evict Non-Evictable Queries")
    func doesNotEvictQueriesThatAreNonEvictable() {
      let store = self.client.store(for: TestQuery().evictWhen(pressure: []))
      self.source.send(pressure: .critical)
      expectNoDifference(self.client.stores(matching: store.path).count, 1)
    }

    @Test("Recognizes Store Retroactively Added To Cache")
    func recognizesStoreRetroactivelyAddedToCache() {
      let store = QueryStore.detached(query: TestQuery(), initialValue: nil)
      self.storeCache.withLock { entries in
        entries.update(OpaqueQueryStore(erasing: store))
      }
      let clientStore = self.client.store(for: TestQuery())
      expectNoDifference(store === clientStore, true)
    }
  }
}

private final class CountingController<State: QueryStateProtocol>: QueryController {
  let count = RecursiveLock(0)

  func control(with controls: QueryControls<State>) -> QuerySubscription {
    self.count.withLock { $0 += 1 }
    return .empty
  }
}
