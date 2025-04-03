import CustomDump
import Dependencies
import SharingQuery
import Testing
import _TestQueries

@Suite("InfiniteQueryKey tests")
struct InfiniteQueryKeyTests {
  @Test("Fetches For Value")
  func fetchesForValue() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "hello", 1: "world"] }
    @Shared(.infiniteQuery(query.enableAutomaticFetching(when: .always(false)))) var value

    expectNoDifference(value.currentValue, [])

    try await value.fetchNextPage()
    expectNoDifference(value.currentValue, [InfiniteQueryPage(id: 0, value: "hello")])

    try await value.fetchNextPage()
    expectNoDifference(
      value.currentValue,
      [InfiniteQueryPage(id: 0, value: "hello"), InfiniteQueryPage(id: 1, value: "world")]
    )
  }

  @Test("Fetches For Error")
  func fetchesForError() async throws {
    @Shared(.infiniteQuery(FailableInfiniteQuery().enableAutomaticFetching(when: .always(false))))
    var value

    expectNoDifference($value.loadError as? FailableInfiniteQuery.SomeError, nil)
    _ = try? await value.fetchNextPage()
    expectNoDifference(
      $value.loadError as? FailableInfiniteQuery.SomeError,
      FailableInfiniteQuery.SomeError()
    )
  }

  @Test("Set Value, Updates Value In Store")
  func setValueUpdatesValueInStore() async throws {
    @Dependency(\.queryClient) var client

    let query = TestInfiniteQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.infiniteQuery(query)) var value

    let expected = InfiniteQueryPagesFor<TestInfiniteQuery>(
      uniqueElements: [InfiniteQueryPage(id: 0, value: "blob")]
    )
    $value.withLock { $0.currentValue = expected }
    expectNoDifference(value.currentValue, expected)
    expectNoDifference(client.store(for: query).currentValue, value.currentValue)
  }

  @Test("Shares State With QueryStateKey")
  func sharesStateWithQueryStateKey() async throws {
    @Dependency(\.queryClient) var client

    let query = TestInfiniteQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.infiniteQuery(query)) var value
    @SharedReader(.infiniteQueryState(query)) var state

    let expected = InfiniteQueryPagesFor<TestInfiniteQuery>(
      uniqueElements: [InfiniteQueryPage(id: 0, value: "blob")]
    )
    $value.withLock { $0.currentValue = expected }
    expectNoDifference(value.currentValue, expected)
    expectNoDifference(state.currentValue, expected)
  }

  @Test("Equatability Is True When Values From Separate Stores Are Equal")
  func equatability() async throws {
    let query = TestInfiniteQuery()
    query.state.withLock { $0 = [0: "blob"] }
    let s1 = QueryStore.detached(query: query)
    let s2 = QueryStore.detached(query: query)

    @Shared(.infiniteQuery(store: s1)) var value1
    @Shared(.infiniteQuery(store: s2)) var value2

    expectNoDifference(value1, value2)

    try await value1.fetchNextPage()
    withExpectedIssue { expectNoDifference(value1, value2) }

    try await value2.fetchNextPage()
    expectNoDifference(value1, value2)
  }

  @Test("Makes Separate Subscribers When Using MutationKey And QueryStateKey In Conjunction")
  func makesSeparateSubscribersWhenUsingMutationKeyAndQueryStateKeyInConjunction() async throws {
    @Dependency(\.queryClient) var client

    let query = TestInfiniteQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.infiniteQuery(query)) var value
    @SharedReader(.infiniteQuery(query)) var state

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }

  @Test("Makes Separate Subscribers When Using MutationKeys With The Same Mutation")
  func makesSeparateSubscribersWhenUsingMutationKeysWithTheSameMutation() async throws {
    @Dependency(\.queryClient) var client

    let query = TestInfiniteQuery().enableAutomaticFetching(when: .always(false))
    @Shared(.infiniteQuery(query)) var value1
    @Shared(.infiniteQuery(query)) var value2

    let store = client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }
}
