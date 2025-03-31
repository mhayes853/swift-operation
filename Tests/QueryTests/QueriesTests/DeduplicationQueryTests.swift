import CustomDump
import Query
import Testing
import _TestQueries

@Suite("DeduplicationQuery tests")
struct DeduplicationQueryTests {
  private let client = QueryClient()

  @Test("Deduplicates Fetches From The Same Store")
  func deduplicatesFetchesSameStore() async throws {
    let query = CountingQuery()
    let store = self.client.store(for: query.deduplicated())
    async let f1 = store.fetch()
    async let f2 = store.fetch()
    _ = try await (f1, f2)
    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Deduplicates Fetches From Different Stores")
  func deduplicatesFetchesDifferentStores() async throws {
    let query = CountingQuery()
    let storeQuery = query.deduplicated()
    let store = self.client.store(for: storeQuery)
    let store2 = self.client.store(for: storeQuery)
    async let f1 = store.fetch()
    async let f2 = store2.fetch()
    _ = try await (f1, f2)
    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Deduplication Supports Cancellation")
  func deduplicationSupportsCancellation() async throws {
    let query = EndlessQuery()
    let store = self.client.store(for: query.deduplicated())
    let task = Task { try await store.fetch() }
    await Task.megaYield()
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test("Fetch Initial Page Concurrently With Deduplication, Only Performs 1 Fetch")
  func fetchInitialPageConcurrentlyReturnsSamePageData() async throws {
    let query = CountingInfiniteQuery()
    let store = self.client.store(for: query.deduplicated())
    async let p1 = store.fetchPreviousPage()
    async let p2 = store.fetchPreviousPage()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Fetch All Pages Concurrently With Deduplication, Only Fetches All Pages Once Each")
  func fetchAllPagesConcurrentlyReturnsSamePageData() async throws {
    let query = CountingInfiniteQuery()
    let store = self.client.store(for: query.deduplicated())
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    await query.resetCount()
    async let p1 = store.fetchAllPages()
    async let p2 = store.fetchAllPages()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(
      count,
      2,
      "The count should be 2 because each page is fetched once, and the 2 tasks should be deduplicated."
    )
  }

  @Test("Fetch Previous Page Concurrently With Deduplication, Only Performs 1 Fetch")
  func fetchPreviousPageConcurrentlyReturnsSamePageData() async throws {
    let query = CountingInfiniteQuery()
    let store = self.client.store(for: query.deduplicated())
    try await store.fetchPreviousPage()
    await query.resetCount()
    async let p1 = store.fetchPreviousPage()
    async let p2 = store.fetchPreviousPage()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Fetch Next Page Concurrently With Deduplication, Only Performs 1 Fetch")
  func fetchNextPageConcurrentlyReturnsSamePageData() async throws {
    let query = CountingInfiniteQuery()
    let store = self.client.store(for: query.deduplicated())
    try await store.fetchNextPage()
    await query.resetCount()
    async let p1 = store.fetchNextPage()
    async let p2 = store.fetchNextPage()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }
}
