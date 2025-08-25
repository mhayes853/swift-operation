import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("RetryQuery tests")
struct RetryQueryTests {
  @Test("Zero Retries, Does Not Perform Any Retries")
  func zeroRetriesDoesNotPerformAnyRetries() async {
    let query = FailingQuery()
      .backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(limit: 0)
      .defaultValue("blob")
    let store = OperationStore.detached(query: query)
    await #expect(throws: FailingQuery.SomeError.self) {
      try await store.fetch()
    }
  }

  @Test("Fetch Errors, Then Retries The Specified Number Of Times")
  func fetchErrorsThenRetriesTheSpecifiedNumberOfTimes() async {
    let query = CountingQuery()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    await query.ensureFails()

    await #expect(throws: CountingQuery.SomeError.self) {
      try await store.fetch()
    }
    let count = await query.fetchCount
    expectNoDifference(count, 4)
  }

  @Test("Succeeds On Second Refetch, Returns Value")
  func succeedsOnSecondRefetchReturnsValue() async throws {
    let query = SucceedOnNthRefetchQuery(index: 2)
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    let value = try await store.fetch()
    expectNoDifference(value, SucceedOnNthRefetchQuery.value)
  }

  @Test("Succeeds On Final Refetch, Returns Value")
  func succeedsOnFinalRefetchReturnsValue() async throws {
    let query = SucceedOnNthRefetchQuery(index: 3)
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    let value = try await store.fetch()
    expectNoDifference(value, SucceedOnNthRefetchQuery.value)
  }

  @Test("Does Not Retry Every Page Fetch When Fetching All Pages")
  func doesNotRetryEveryPageFetchWhenFetchingAllPages() async throws {
    let query = FlakeyInfiniteQuery()
    query.values.withLock { $0.failOnPageId = -1 }
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3)
    )
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.values.withLock {
      $0.failOnPageId = 2
      $0.fetchCount = 0
    }
    _ = try? await store.refetchAllPages()
    query.values.withLock {
      expectNoDifference(
        $0.fetchCount,
        6,
        "The fetch count should account for fetching the first 2 pages successfully, and then retrying just the third page 3 times after the initial attempt."
      )
    }
  }

  @Test("Max Retries Is Based Off Of Limit")
  func maxRetriesIsBasedOffOfLimit() async throws {
    let query = FailingQuery().backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(limit: 10)
    let store = OperationStore.detached(query: query, initialValue: nil)
    expectNoDifference(store.context.operationMaxRetries, 10)
  }

  @Test("Uses Context Max Retries Over Query Limit")
  func usesContextMaxRetriesOverQueryLimit() async throws {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    store.context.operationMaxRetries = 10
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 11)
  }

  @Test("Delays Between Retries Using The Specified Backoff Function")
  func delaysBetweenRetries() async throws {
    let delayer = TestDelayer()
    let query = FailingQuery()
      .delayer(delayer)
      .backoff(.linear(1000))
      .retry(limit: 5)
    let store = OperationStore.detached(query: query, initialValue: nil)
    _ = try? await store.fetch()
    expectNoDifference(delayer.delays, [1000, 2000, 3000, 4000, 5000])
  }
}
