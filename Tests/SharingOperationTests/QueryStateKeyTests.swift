import CustomDump
import IssueReporting
import OperationTestHelpers
import SharingOperation
import Testing

@Suite("QueryStateKey tests")
struct QueryStateKeyTests {
  private let client = QueryClient()

  @Test("Uses Current Store State")
  func usesCurrentStoreState() async throws {
    let query = TestQuery().disableAutomaticFetching()
    let store = self.client.store(for: query)
    try await store.fetch()

    @SharedQuery(query, client: self.client) var state

    expectNoDifference(state, TestQuery.value)
  }

  @Test("Fetches Value")
  func fetchesValues() async throws {
    @SharedQuery(TestQuery(), client: self.client) var state

    expectNoDifference($state.status.isSuccessful, false)
    expectNoDifference($state.shared.wrappedValue, nil)
    _ = try await self.client.store(for: TestQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference($state.status.isSuccessful, true)
    expectNoDifference($state.shared.wrappedValue, TestQuery.value)
  }

  #if canImport(SwiftUI)
    @Test("Fetches Value With Animation, Completes Synchronously For Testing")
    func fetchesValuesWithAnimationCompletesSynchronouslyForTesting() async throws {
      @SharedQuery(
        TestQuery().disableAutomaticFetching(),
        client: self.client,
        animation: .bouncy()
      ) var state

      expectNoDifference($state.status.isSuccessful, false)
      _ = try await $state.load()
      expectNoDifference($state.status.isSuccessful, true)
    }
  #endif

  @Test("Fetches Error")
  func fetchesError() async throws {
    @SharedQuery(FailingQuery(), client: self.client) var state

    expectNoDifference($state.error as? FailingQuery.SomeError, nil)
    expectNoDifference($state.shared.loadError as? FailingQuery.SomeError, nil)
    _ = try? await self.client.store(for: FailingQuery()).activeTasks.first?.runIfNeeded()
    expectNoDifference($state.error as? FailingQuery.SomeError, FailingQuery.SomeError())
    expectNoDifference($state.shared.loadError as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Refetches Error")
  func refetchesError() async throws {
    let query = FlakeyQuery()
    @SharedQuery(query, client: self.client) var state

    _ = try? await self.client.store(for: FlakeyQuery()).activeTasks.first?.runIfNeeded()

    await query.ensureFailure()
    expectNoDifference($state.error as? FlakeyQuery.SomeError, nil)

    await #expect(throws: Error.self) {
      try await $state.fetch()
    }
    expectNoDifference($state.error as? FlakeyQuery.SomeError, FlakeyQuery.SomeError())
  }

  @Test("Only Has One Active Task When Loading Initial Data")
  func onlyHasOneActiveTaskWhenLoadingInitialData() async throws {
    @SharedQuery(EndlessQuery(), client: self.client) var state

    expectNoDifference($state.activeTasks.count, 1)
  }

  @Test("Refetches Value")
  func refetchesValues() async throws {
    @SharedQuery(TestQuery(), client: self.client) var state
    let store = self.client.store(for: TestQuery())

    _ = try await store.activeTasks.first?.runIfNeeded()
    store.currentValue = nil
    expectNoDifference(state, nil)

    try await $state.fetch()
    expectNoDifference(state, TestQuery.value)
  }

  @Test("Does Not Start Fetch Task When Automatic Fetching Is Disabled")
  func doesNotStartFetchTaskWhenAutomaticFetchingIsDisabled() async throws {
    let query = TestQuery().disableAutomaticFetching()
    let store = self.client.store(for: query)

    @SharedQuery(store: store) var state

    expectNoDifference(store.activeTasks, [])
  }

  @Test("Restarts Loading State When Triggering Fetch On Store")
  func restartsLoadingStateWhenTriggeringFetchOnStore() async throws {
    let query = TestQuery().disableAutomaticFetching()
    let store = self.client.store(for: query)

    @SharedQuery(store: store) var state

    expectNoDifference($state.isLoading, false)
    expectNoDifference($state.shared.isLoading, false)

    let subscriber = store.subscribe(
      with: QueryEventHandler(
        onFetchingStarted: { [s = $state] _ in
          expectNoDifference(s.isLoading, true)
          expectNoDifference(s.shared.isLoading, true)
        }
      )
    )
    try await store.fetch()
    subscriber.cancel()
  }

  @Test("Is Not In Initial Loading State When Automatic Fetching Is Disabled")
  func notInInitialLoadingStateWhenAutomaticFetchingIsDisabled() async throws {
    let query = TestQuery().disableAutomaticFetching()
    let store = self.client.store(for: query)

    @SharedQuery(store: store) var state

    expectNoDifference($state.isLoading, false)
  }

  @Test("Is In Initial Loading State When Automatic Fetching Enabled On Query")
  func isInInitialLoadingStateWhenAutomaticFetchingEnabledOnQuery() async throws {
    let query = EndlessQuery().enableAutomaticFetching(onlyWhen: .always(true))
    let store = self.client.store(for: query)

    @SharedQuery(store: store) var state

    expectNoDifference($state.isLoading, true)
  }

  @Test("Yields Multiple Values To Query Whilst Remaining In A Loading State")
  func yieldsMultipleValuesToQueryWhilstRemainingInALoadingState() async throws {
    let query = ContinuingQuery()
    let store = self.client.store(for: query.enableAutomaticFetching(onlyWhen: .always(true)))

    @SharedQuery(store: store) var state
    query.onYield = { _ in
      expectNoDifference(state != nil, true)
      expectNoDifference(state != ContinuingQuery.finalValue, true)
      expectNoDifference($state.isLoading, true)
    }

    expectNoDifference(state, nil)

    _ = try await store.activeTasks.first?.runIfNeeded()

    expectNoDifference($state.isLoading, false)
    expectNoDifference(state, ContinuingQuery.finalValue)
  }

  @Test("Makes Separate Subscribers When Using QueryStateKeys With The Same Query")
  func makesSeparateSubscribersWhenUsingQueryStateKeysWithTheSameQuery() async throws {
    let query = TestQuery().disableAutomaticFetching()
    @SharedQuery(query, client: self.client) var value
    @SharedQuery(query, client: self.client) var state

    let store = self.client.store(for: query)
    expectNoDifference(store.subscriberCount, 2)
  }
}
