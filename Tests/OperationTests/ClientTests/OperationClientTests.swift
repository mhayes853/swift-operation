import CustomDump
import IssueReporting
@_spi(Warnings) import Operation
@_spi(Warnings) import OperationTestHelpers
import Testing

@Suite("OperationClient tests")
struct OperationClientTests {
  @Test("Maintains The Same Query State For Multiple Stores With The Same Query")
  func maintainsValueForMultipleStores() async throws {
    let client = OperationClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1.currentValue, store2.currentValue)
    expectNoDifference(store2.currentValue, TestQuery.value)
  }

  @Test("Returns Same Store Reference For Same Query")
  func returnsSameStoreReferenceForSameQuery() async throws {
    let client = OperationClient()
    let store1 = client.store(for: TestQuery())
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1 === store2, true)
  }

  @Test("Reports Issue When Different Query Type Has The Same Path As Another Query")
  func cannotHaveDuplicatePaths() async throws {
    let client = OperationClient()
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
    let client = OperationClient()
    _ = client.store(for: TestQuery())
    withExpectedIssue {
      let store = client.store(for: TestQuery().defaultValue(TestQuery.value + 10))
      _ = store.currentValue
    }
  }

  @Test("Does Not Share States Between Different Queries")
  func doesNotShareStateBetweenDifferentQueries() async throws {
    let client = OperationClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestStringQuery().defaultValue("bar"))

    expectNoDifference(store1.currentValue, TestQuery.value)
    expectNoDifference(store2.currentValue, "bar")
  }

  @Test("Loads Queries Matching Path Prefix")
  func matchesPathPrefix() async throws {
    let client = OperationClient()
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
    let client = OperationClient()
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
    let client = OperationClient()
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
    let client = OperationClient()
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
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let store = client.store(for: q1)
    let opaqueStore = try #require(client.stores(matching: []).first)

    opaqueStore.uncheckedSetCurrentValue(20)
    expectNoDifference(store.currentValue, 20)
  }

  @Test("Sets Result For Store Through Path")
  func setResultForStoreThroughPath() async throws {
    struct SomeError: Equatable, Error {}

    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let store = client.store(for: q1)
    let opaqueStore = try #require(client.stores(matching: []).first)

    opaqueStore.uncheckedSetResult(to: .success(20))
    expectNoDifference(store.currentValue, 20)

    opaqueStore.uncheckedSetResult(to: .failure(SomeError()))
    expectNoDifference(store.error as? SomeError, SomeError())
  }

  @Test("Uses Default Value For AnyOperationStore")
  func defaultAnyOperationStoreValue() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    _ = client.store(for: q1)

    let stores = client.stores(matching: [])
    try #require(stores.count == 1)

    expectNoDifference(stores[q1.path]?.currentValue as? Int, 10)
    expectNoDifference(stores[q1.path]?.initialValue as? Int, 10)
  }

  @Test("Adds Current OperationClient Instance To The OperationContext")
  func OperationClientInContext() async throws {
    let client = OperationClient()
    let query = ContextReadingQuery()
    let store = client.store(for: query)
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.operationClient)
    expectNoDifference(client === contextClient, true)
  }

  @Test("Sets Custom OperationClient Instance To The OperationContext")
  func setCustomOperationClientInContext() async throws {
    let client = OperationClient()
    let query = ContextReadingQuery()
    let store = OperationStore.detached(query: query, initialValue: nil)
    store.context.operationClient = client
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.operationClient)
    expectNoDifference(client === contextClient, true)
  }

  @Test("Loads AnyStore In A Loading State")
  func loadAnyStoreInLoadingState() async throws {
    let client = OperationClient()
    let query = SleepingQuery()
    let store = client.store(for: query)
    query.didBeginSleeping = {
      let anyStore = client.store(with: query.path)
      expectNoDifference(anyStore?.isLoading, true)
      query.resume()
    }
    try await store.fetch()
  }

  @Test("No AnyStore For OperationPath That Does Not Exist")
  func noAnyStoreForOperationPathThatDoesNotExist() async throws {
    let client = OperationClient()
    let store = client.store(with: [1, 2, 3])
    expectNoDifference(store == nil, true)
  }

  @Test("Only Subscribes To OperationController Once Per Store")
  func onlySubscribesToOperationControllerOncePerStore() async throws {
    let client = OperationClient()
    let controller = CountingController<TestQuery.State>()
    let query = TestQuery().controlled(by: controller)
    let store = client.store(for: query)
    _ = client.store(for: query)
    controller.count.withLock { expectNoDifference($0, 1) }
    _ = store
  }

  @Test("Resets Query State From Store Through Path")
  func resetQueryStateFromStoreThroughPath() async throws {
    let client = OperationClient()
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
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    let q4 = PathableQuery(value: 3, path: [2, 5]).defaultValue(40)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.withStores(matching: [1]) { entries, createStore in
      expectNoDifference(entries.count, 2)
      entries[q1.path]?.uncheckedSetCurrentValue(50)
      entries.update(OpaqueOperationStore(erasing: createStore(for: q4)))
      entries.removeValue(forPath: q2.path)
    }

    expectNoDifference(client.stores(matching: []).count, 3)
    expectNoDifference(client.store(for: q1).currentValue, 50)
    expectNoDifference(client.store(with: q2.path) == nil, true)
    expectNoDifference(client.store(for: q4).currentValue, 40)
  }

  @Test("Mutate Store Entries")
  func mutateStoreEntries() {
    let client = OperationClient()
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
    ) { entries, createStore in
      expectNoDifference(entries.count, 2)
      entries[q1.path]?.currentValue = 50
      entries.update(createStore(for: q5))
      entries.removeValue(forPath: q2.path)
    }

    expectNoDifference(client.stores(matching: []).count, 4)
    expectNoDifference(client.store(for: q1).currentValue, 50)
    expectNoDifference(client.store(with: q2.path) == nil, true)
    expectNoDifference(client.store(for: q5).currentValue, 40)
  }

  @Test("Nested WithStores")
  func nestedWithStores() {
    let client = OperationClient()
    let isEmpty = client.withStores(matching: OperationPath()) { _, _ in
      client.withStores(matching: OperationPath()) { stores, c in
        stores.isEmpty
      }
    }
    expectNoDifference(isEmpty, true)
  }
}

private final class CountingController<State: OperationState>: OperationController {
  let count = RecursiveLock(0)

  func control(with controls: OperationControls<State>) -> OperationSubscription {
    self.count.withLock { $0 += 1 }
    return .empty
  }
}
