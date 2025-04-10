import CustomDump
import IssueReporting
import SharingQuery
import Testing
import _TestQueries

@Suite("QueryStateKey tests")
struct QueryStateKeyTests {
  private let client = QueryClient()

  @Test("Uses Current Store State")
  func usesCurrentStoreState() async throws {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
    let store = self.client.store(for: query)
    try await store.fetch()

    @SharedReader(.queryState(query, initialValue: nil, client: self.client)) var state

    expectNoDifference(state.currentValue, TestQuery.value)
  }

  @Test("Fetches Value")
  func fetchesValues() async throws {
    @SharedReader(.queryState(TestQuery(), initialValue: nil, client: self.client)) var state

    expectNoDifference(state.status.isSuccessful, false)
    _ = try await self.client.store(for: TestQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference(state.status.isSuccessful, true)
  }

  @Test("Fetches Error")
  func fetchesError() async throws {
    @SharedReader(.queryState(FailingQuery(), initialValue: nil, client: self.client))
    var state

    expectNoDifference($state.loadError as? FailingQuery.SomeError, nil)
    _ = try? await self.client.store(for: FailingQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference($state.loadError as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Refetches Error")
  func refetchesError() async throws {
    let query = FlakeyQuery()
    @SharedReader(.queryState(query, initialValue: nil, client: self.client))
    var state

    _ = try? await self.client.store(for: FlakeyQuery()).activeTasks.first?.runIfNeeded()

    await query.ensureFailure()
    expectNoDifference($state.loadError as? FlakeyQuery.SomeError, nil)

    await #expect(throws: Error.self) {
      try await $state.load()
    }
    expectNoDifference($state.loadError as? FlakeyQuery.SomeError, FlakeyQuery.SomeError())
  }

  @Test("Only Has One Active Task When Loading Initial Data")
  func onlyHasOneActiveTaskWhenLoadingInitialData() async throws {
    @SharedReader(.queryState(EndlessQuery(), initialValue: nil, client: self.client))
    var state

    let store = self.client.store(for: EndlessQuery())
    await Task.megaYield()

    expectNoDifference(store.activeTasks.count, 1)
  }

  @Test("Refetches Value")
  func refetchesValues() async throws {
    @SharedReader(.queryState(TestQuery(), initialValue: nil, client: self.client)) var state
    let store = self.client.store(for: TestQuery())

    _ = try await store.activeTasks.first?.runIfNeeded()
    store.currentValue = nil
    expectNoDifference(state.currentValue, nil)

    try await $state.load()
    expectNoDifference(state.currentValue, TestQuery.value)
  }

  @Test("Does Not Start Fetch Task When Automatic Fetching Is Disabled")
  func doesNotStartFetchTaskWhenAutomaticFetchingIsDisabled() async throws {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
    let store = self.client.store(for: query)

    @SharedReader(.queryState(store: store)) var state

    expectNoDifference(store.activeTasks, [])
  }

  @Test("Restarts Loading State When Triggering Fetch On Store")
  func restartsLoadingStateWhenTriggeringFetchOnStore() async throws {
    let query = EndlessQuery().enableAutomaticFetching(onlyWhen: .always(false))
    let store = self.client.store(for: query)

    @SharedReader(.queryState(store: store)) var state

    expectNoDifference($state.isLoading, false)
    Task { try await store.fetch() }
    await Task.megaYield()
    expectNoDifference($state.isLoading, true)
  }

  @Test("Is Not In Initial Loading State When Automatic Fetching Is Disabled")
  func notInInitialLoadingStateWhenAutomaticFetchingIsDisabled() async throws {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
    let store = self.client.store(for: query)

    @SharedReader(.queryState(store: store)) var state

    expectNoDifference($state.isLoading, false)
  }

  @Test("Is In Initial Loading State When Automatic Fetching Enabled On Query")
  func isInInitialLoadingStateWhenAutomaticFetchingEnabledOnQuery() async throws {
    let query = EndlessQuery().enableAutomaticFetching(onlyWhen: .always(true))
    let store = self.client.store(for: query)

    @SharedReader(.queryState(store: store)) var state

    expectNoDifference($state.isLoading, true)
  }

  @Test("Yields Multiple Values To Query Whilst Remaining In A Loading State")
  func yieldsMultipleValuesToQueryWhilstRemainingInALoadingState() async throws {
    let query = ContinuingQuery()
    let store = self.client.store(for: query.enableAutomaticFetching(onlyWhen: .always(true)))

    @SharedReader(.queryState(store: store)) var state
    query.onYield = { _ in
      expectNoDifference(state.currentValue != nil, true)
      expectNoDifference(state.currentValue != ContinuingQuery.finalValue, true)
      expectNoDifference($state.isLoading, true)
    }

    expectNoDifference(state.currentValue, nil)

    _ = try await store.activeTasks.first?.runIfNeeded()

    expectNoDifference($state.isLoading, false)
    expectNoDifference(state.currentValue, ContinuingQuery.finalValue)
  }

  @Test("Makes Separate Subscribers When Using QueryStateKeys With The Same Query")
  func makesSeparateSubscribersWhenUsingQueryStateKeysWithTheSameQuery() async throws {
    let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
    @SharedReader(.queryState(query, initialValue: nil, client: self.client)) var value
    @SharedReader(.queryState(query, initialValue: nil, client: self.client)) var state

    let store = self.client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }
}
