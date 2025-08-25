import CustomDump
import Dependencies
@_spi(Warnings) import OperationTestHelpers
@_spi(Warnings) import SharingOperation
import Testing

@Suite("QueryKey tests")
struct QueryKeyTests {
  @Test("Fetches Value")
  func fetchesValue() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().withTaskMegaYield()

    @SharedOperation(query) var value

    expectNoDifference(value, nil)
    _ = try await client.store(for: query).activeTasks.first?.runIfNeeded()
    expectNoDifference(value, TestQuery.value)
  }

  @Test("Fetches Error")
  func fetchesError() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = FailingQuery().withTaskMegaYield()

    @SharedOperation(query) var value

    expectNoDifference($value.error as? FailingQuery.SomeError, nil)
    _ = try? await client.store(for: query).activeTasks.first?.runIfNeeded()
    expectNoDifference($value.error as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Set Value, Updates Value In Store")
  func setValueUpdatesValueInStore() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedOperation(query) var value

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(client.store(for: query).currentValue, value)
  }

  @Test("Shares State With Shared Queries")
  func sharesStateWithSharedQueries() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedOperation(query) var value
    @SharedOperation(query) var state

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(state, value)
  }

  @Test("Makes Separate Subscribers When Using QueryKey And OperationStateKey In Conjunction")
  func makesSeparateSubscribersWhenUsingQueryKeyAndOperationStateKeyInConjunction() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedOperation(query) var value
    @SharedOperation(query) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Makes Separate Subscribers When Using QueryKeys With The Same Query")
  func makesSeparateSubscribersWhenUsingQueryKeysWithTheSameQuery() async throws {
    @Dependency(\.defaultOperationClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedOperation(query) var value
    @SharedOperation(query) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Backed Query Is Not Unbacked")
  func backedQueryIsBacked() async throws {
    @SharedOperation(TestQuery().disableAutomaticFetching()) var value
    expectNoDifference($value.isBacked, true)
  }

  @Test("Unbacked Query")
  func unbackedQuery() async throws {
    @SharedOperation<TestQuery.State> var value = TestQuery.value
    expectNoDifference(value, TestQuery.value)
    expectNoDifference($value.isBacked, false)
  }

  @Test("Unbacked Mutation")
  func unbackedMutation() async throws {
    @SharedOperation<EmptyMutation.State> var value = "blob"
    expectNoDifference(value, "blob")
    expectNoDifference($value.isBacked, false)
  }

  @Test("Reports Issue When Fetching Unbacked Query")
  func reportsIssueWhenFetchingUnbackedQuery() async throws {
    @SharedOperation<TestQuery.State> var value = TestQuery.value

    await #expect(throws: Error.self) {
      try await withKnownIssue {
        try await $value.fetch()
      } matching: { issue in
        issue.comments.contains(.warning(.unbackedQueryFetch(type: TestQuery.State.self)))
      }
    }
  }
}
