import CustomDump
import QueryCore
import Testing

@Suite("RetryQuery tests")
struct RetryQueryTests {
  @Test("Zero Retries, Does Not Perform Any Retries")
  func zeroRetriesDoesNotPerformAnyRetries() async {
    let query = FailingQuery().retry(limit: 0, backoff: .noBackoff).defaultValue("blob")
    let store = QueryStoreFor<FailingQuery>.detached(query: query)
    await #expect(throws: FailingQuery.SomeError.self) {
      try await store.fetch()
    }
  }

  @Test("Fetch Errors, Then Retries The Specified Number Of Times")
  func fetchErrorsThenRetriesTheSpecifiedNumberOfTimes() async {
    let query = CountingQuery()
    let store = QueryStoreFor<CountingQuery>
      .detached(query: query.retry(limit: 3, backoff: .noBackoff), initialValue: nil)
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
    let store = QueryStoreFor<SucceedOnNthRefetchQuery>
      .detached(query: query.retry(limit: 3, backoff: .noBackoff), initialValue: nil)
    let value = try await store.fetch()
    expectNoDifference(value, SucceedOnNthRefetchQuery.value)
  }

  @Test("Succeeds On Final Refetch, Returns Value")
  func succeedsOnFinalRefetchReturnsValue() async throws {
    let query = SucceedOnNthRefetchQuery(index: 3)
    let store = QueryStoreFor<SucceedOnNthRefetchQuery>
      .detached(query: query.retry(limit: 3, backoff: .noBackoff), initialValue: nil)
    let value = try await store.fetch()
    expectNoDifference(value, SucceedOnNthRefetchQuery.value)
  }

  @Test("Max Retries Is Based Off Of Limit")
  func maxRetriesIsBasedOffOfLimit() async throws {
    let query = FailingQuery().retry(limit: 10, backoff: .noBackoff)
    let store = QueryStoreFor<FailingQuery>
      .detached(query: query.retry(limit: 3, backoff: .noBackoff), initialValue: nil)
    expectNoDifference(store.context.maxRetryIndex, 10)
  }
}
