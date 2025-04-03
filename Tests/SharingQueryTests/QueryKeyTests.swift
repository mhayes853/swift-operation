import CustomDump
import Dependencies
import SharingQuery
import Testing
import _TestQueries

@Suite("QueryKey tests")
struct QueryKeyTests {
  @Test("Fetches Value")
  func fetchesValue() async throws {
    @Dependency(\.queryClient) var client

    @Shared(.query(TestQuery(), initialValue: nil)) var value

    expectNoDifference(value, nil)
    _ = try await client.store(for: TestQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference(value, TestQuery.value)
  }

  @Test("Fetches Error")
  func fetchesError() async throws {
    @Dependency(\.queryClient) var client

    @Shared(.query(FailingQuery(), initialValue: nil)) var value

    expectNoDifference($value.loadError as? FailingQuery.SomeError, nil)
    _ = try? await client.store(for: FailingQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference($value.loadError as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Set Value, Updates Value In Store")
  func setValueUpdatesValueInStore() async throws {
    @Dependency(\.queryClient) var client

    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.query(query, initialValue: nil)) var value

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(client.store(for: query).currentValue, value)
  }

  @Test("Shares State With QueryStateKey")
  func sharesStateWithQueryStateKey() async throws {
    @Dependency(\.queryClient) var client

    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.query(query, initialValue: nil)) var value
    @SharedReader(.queryState(query, initialValue: nil)) var state

    $value.withLock { $0 = TestQuery.value + 1 }
    expectNoDifference(value, TestQuery.value + 1)
    expectNoDifference(state.currentValue, value)
  }

  @Test("Makes Separate Subscribers When Using QueryKey And QueryStateKey In Conjunction")
  func makesSeparateSubscribersWhenUsingQueryKeyAndQueryStateKeyInConjunction() async throws {
    @Dependency(\.queryClient) var client

    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.query(query, initialValue: nil)) var value
    @SharedReader(.queryState(query, initialValue: nil)) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Makes Separate Subscribers When Using QueryKeys With The Same Query")
  func makesSeparateSubscribersWhenUsingQueryKeysWithTheSameQuery() async throws {
    @Dependency(\.queryClient) var client

    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.query(query, initialValue: nil)) var value
    @SharedReader(.query(query, initialValue: nil)) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }
}
