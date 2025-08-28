import CustomDump
import Operation
import OperationTestHelpers
import XCTest

final class DeduplicationQueryTests: XCTestCase {
  func testDeduplicatesFetchesSameStore() async throws {
    let query = DeduplicationQuery()
    let store = OperationStore.detached(query: query.deduplicated(), initialValue: nil)
    async let f1 = store.fetch()
    async let f2 = store.fetch()
    _ = try await (f1, f2)
    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  func testDeduplicationSupportsCancellation() async throws {
    let query = EndlessQuery()
    let store = OperationStore.detached(query: query.deduplicated(), initialValue: nil)
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      try await store.fetch()
    }
    await XCTAssertThrows(try await task.value, error: CancellationError.self)
  }

  func testFetchInitialPageConcurrentlyPerformsOneFetch() async throws {
    let query = DeduplicationInfiniteQuery()
    let store = OperationStore.detached(query: query.deduplicated())
    async let p1 = store.fetchPreviousPage()
    async let p2 = store.fetchPreviousPage()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  func testFetchAllPagesConcurrentlyFetchesAllPagesOnceEach() async throws {
    let query = DeduplicationInfiniteQuery()
    let store = OperationStore.detached(query: query.deduplicated())
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    await query.resetCount()
    async let p1 = store.refetchAllPages()
    async let p2 = store.refetchAllPages()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(
      count,
      2,
      "The count should be 2 because each page is fetched once, and the 2 tasks should be deduplicated."
    )
  }

  func testFetchPreviousPageConcurrentlyPerformsOneFetch() async throws {
    let query = DeduplicationInfiniteQuery()
    let store = OperationStore.detached(query: query.deduplicated())
    try await store.fetchPreviousPage()
    await query.resetCount()
    async let p1 = store.fetchPreviousPage()
    async let p2 = store.fetchPreviousPage()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  func testFetchNextPageConcurrentlyPerformsOneFetch() async throws {
    let query = DeduplicationInfiniteQuery()
    let store = OperationStore.detached(query: query.deduplicated())
    try await store.fetchNextPage()
    await query.resetCount()
    async let p1 = store.fetchNextPage()
    async let p2 = store.fetchNextPage()
    _ = try await (p1, p2)

    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }
}

private final actor DeduplicationQuery: QueryRequest, Identifiable {
  private(set) var fetchCount = 0

  func resetCount() {
    self.fetchCount = 0
  }

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<String>
  ) async throws -> String {
    // NB: Give enough time for deduplication.
    try await TaskSleepDelayer.taskSleep.delay(for: 0.1)
    await isolate(self) { @Sendable in $0.fetchCount += 1 }
    return "blob"
  }
}

private final actor DeduplicationInfiniteQuery: InfiniteQueryRequest, Identifiable {
  nonisolated let initialPageId = 0

  private(set) var fetchCount = 0

  func resetCount() {
    self.fetchCount = 0
  }

  nonisolated func pageId(
    after page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: OperationContext
  ) -> Int? {
    page.id + 1
  }

  nonisolated func pageId(
    before page: InfiniteQueryPage<Int, String>,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: OperationContext
  ) -> Int? {
    page.id - 1
  }

  func fetchPage(
    isolation: isolated (any Actor)?,
    using paging: InfiniteQueryPaging<Int, String>,
    in context: OperationContext,
    with continuation: OperationContinuation<String>
  ) async throws -> String {
    // NB: Give enough time for deduplication.
    try await TaskSleepDelayer.taskSleep.delay(for: 0.1)
    await isolate(self) { @Sendable in $0.fetchCount += 1 }
    return "blob"
  }
}
