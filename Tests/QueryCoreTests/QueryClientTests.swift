import CustomDump
import IssueReporting
@_spi(Warnings) import QueryCore
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

    let stores = client.queries(matching: [1])
    try #require(stores.count == 2)

    expectNoDifference(stores[q1.path]?.currentValue as? Int, nil)
    expectNoDifference(stores[q3.path]?.currentValue as? Int, 3)

    try await stores[q1.path]?.fetch()
    expectNoDifference(stores[q1.path]?.currentValue as? Int, 1)
  }

  @Test("Uses Default Value For AnyQueryStore")
  func defaultAnyQueryStoreValue() async throws {
    let client = QueryClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    _ = client.store(for: q1)

    let stores = client.queries(matching: [])
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
    let store = QueryStoreFor<ContextReadingQuery>.detached(query: query, initialValue: nil)
    store.context.queryClient = client
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.queryClient)
    expectNoDifference(client === contextClient, true)
  }
}
