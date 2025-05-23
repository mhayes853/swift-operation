import CustomDump
import Dependencies
import QueryTestHelpers
import SharingQuery
import Testing

@Suite("QueryKey tests")
struct QueryKeyTests {
  @Test("Fetches Value")
  func fetchesValue() async throws {
    @Dependency(\.defaultQueryClient) var client

    @SharedQuery(TestQuery()) var value

    expectNoDifference(value, nil)
    _ = try await client.store(for: TestQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference(value, TestQuery.value)
  }

  @Test("Fetches Error")
  func fetchesError() async throws {
    @Dependency(\.defaultQueryClient) var client

    @SharedQuery(FailingQuery()) var value

    expectNoDifference($value.error as? FailingQuery.SomeError, nil)
    _ = try? await client.store(for: FailingQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference($value.error as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Set Value, Updates Value In Store")
  func setValueUpdatesValueInStore() async throws {
    @Dependency(\.defaultQueryClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedQuery(query) var value

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(client.store(for: query).currentValue, value)
  }

  @Test("Shares State With Shared Queries")
  func sharesStateWithSharedQueries() async throws {
    @Dependency(\.defaultQueryClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedQuery(query) var value
    @SharedQuery(query) var state

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(state, value)
  }

  @Test("Makes Separate Subscribers When Using QueryKey And QueryStateKey In Conjunction")
  func makesSeparateSubscribersWhenUsingQueryKeyAndQueryStateKeyInConjunction() async throws {
    @Dependency(\.defaultQueryClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedQuery(query) var value
    @SharedQuery(query) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Makes Separate Subscribers When Using QueryKeys With The Same Query")
  func makesSeparateSubscribersWhenUsingQueryKeysWithTheSameQuery() async throws {
    @Dependency(\.defaultQueryClient) var client

    let query = TestQuery().disableAutomaticFetching()
    @SharedQuery(query) var value
    @SharedQuery(query) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }
}
