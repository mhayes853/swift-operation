import Clocks
import CustomDump
import QueryCore
import Testing

@Suite("QueryStore tests")
struct QueryStoreTests {
  private let client = QueryClient()

  @Test("Store Has Default Value Initially")
  func hasDefaultValue() {
    let defaultValue = TestQuery.value + 1
    let store = self.client.store(for: TestQuery().defaultValue(defaultValue))
    expectNoDifference(store.currentValue, defaultValue)
  }

  @Test("Store Has Nil Value Initially")
  func hasNilValue() {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Has Fetched Value After Fetching")
  func fetchedValue() async throws {
    let store = self.client.store(for: TestQuery())
    let value = try await store.fetch()
    expectNoDifference(value, TestQuery.value)
    expectNoDifference(store.currentValue, TestQuery.value)
  }

  @Test("Is In A Loading State When Fetching")
  func loadingState() async throws {
    let clock = TestClock()
    let query = SleepingQuery(clock: clock, duration: .seconds(1))
    let store = self.client.store(for: query)
    query.didBeginSleeping = {
      expectNoDifference(store.isLoading, true)
      Task { await clock.advance(by: .seconds(1)) }
    }
    expectNoDifference(store.isLoading, false)
    try await store.fetch()
    expectNoDifference(store.isLoading, false)
  }

  @Test("Stores The Error When Fetching Fails")
  func storesError() async throws {
    let store = self.client.store(for: FailingQuery())
    expectNoDifference(store.error as? FailingQuery.SomeError, nil)
    let value = try? await store.fetch()
    expectNoDifference(value, nil)
    expectNoDifference(store.currentValue, nil)
    expectNoDifference(store.error as? FailingQuery.SomeError, FailingQuery.SomeError())
  }

  @Test("Fetch Twice, Returns Different Values")
  func fetchTwiceReturnsDifferentValues() async throws {
    let query = CountingQuery()
    let store = self.client.store(for: query)
    let f1 = try await store.fetch()
    let f2 = try await store.fetch()
    expectNoDifference(f1, 1)
    expectNoDifference(f2, 2)
  }

  @Test("Fetch Cancellation")
  func fetchCancellation() async throws {
    let store = self.client.store(for: EndlessQuery())
    let task = Task { try await store.fetch() }
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test("Increments Value Update Count With Each Fetch")
  func incrementsValueUpdateCount() async throws {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.valueUpdateCount, 0)
    try await store.fetch()
    try await store.fetch()
    expectNoDifference(store.valueUpdateCount, 2)
  }

  @Test("Updates Value Update Date With Each Fetch")
  func updatesValueUpdateDate() async throws {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.valueLastUpdatedAt, nil)
    try await store.fetch()
    let d1 = try #require(store.valueLastUpdatedAt)
    try await store.fetch()
    expectNoDifference(try #require(store.valueLastUpdatedAt) > d1, true)
  }

  @Test("Increments Error Update Count With Each Error")
  func incrementsErrorUpdateCount() async throws {
    let store = self.client.store(for: FailingQuery())
    expectNoDifference(store.errorUpdateCount, 0)
    _ = try? await store.fetch()
    _ = try? await store.fetch()
    expectNoDifference(store.errorUpdateCount, 2)
  }

  @Test("Updates Error Update Date With Each Error")
  func updatesErrorUpdateDate() async throws {
    let store = self.client.store(for: FailingQuery())
    expectNoDifference(store.errorLastUpdatedAt, nil)
    _ = try? await store.fetch()
    let d1 = try #require(store.errorLastUpdatedAt)
    _ = try? await store.fetch()
    expectNoDifference(try #require(store.errorLastUpdatedAt) > d1, true)
  }

  @Test("Clears Error When Fetched Successfully")
  func clearsErrorOnSuccess() async throws {
    let query = FlakeyQuery()
    await query.ensureFailure()
    let store = self.client.store(for: query)
    _ = try? await store.fetch()
    expectNoDifference(store.error != nil, true)
    await query.ensureSuccess(result: "test")
    try await store.fetch()
    expectNoDifference(store.error == nil, true)
  }

  @Test("Updates QueryContext")
  func updatesQueryContext() async throws {
    let query = ContextReadingQuery()
    let store = self.client.store(for: query)
    store.context.test = "blob"
    try await store.fetch()
    let context = await query.latestContext
    expectNoDifference(context?.test, "blob")
  }

  @Test("Starts Fetching By Default When Query Store Subscribed To")
  func startsFetchingOnSubscription() async throws {
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let store = self.client.store(for: TestQuery())
    let subscription = store.subscribe(with: collector.eventHandler())
    await Task.megaYield()
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.success(TestQuery.value)),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Only Starts Fetching For The First Query Subscriber")
  func startsFetchingOnFirstSubscription() async throws {
    let query = CountingQuery {}
    let store = self.client.store(for: query)
    let s1 = store.subscribe(with: QueryEventHandler())
    let s2 = store.subscribe(with: QueryEventHandler())
    let s3 = store.subscribe(with: QueryEventHandler())
    await Task.megaYield()
    let count = await query.fetchCount
    expectNoDifference(count, 1)
    s1.cancel()
    s2.cancel()
    s3.cancel()
  }

  @Test("Subscribe, Unsubscribe, Then Subscribe Again, Emits Events Both Times")
  func subscribeUnsubscribeThenSubscribeAgainEmitsEventsBothTimes() async throws {
    let collector = QueryStoreEventsCollector<FailingQuery.State>()
    let store = self.client.store(for: FailingQuery())
    var subscription = store.subscribe(with: collector.eventHandler())
    _ = try? await store.tasks.first?.runIfNeeded()
    await Task.megaYield()
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.failure(FailingQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
    collector.reset()
    subscription = store.subscribe(with: collector.eventHandler())
    _ = try? await store.tasks.first?.runIfNeeded()
    await Task.megaYield()
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.failure(FailingQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Emits Error Event When Fetching Fails")
  func emitsErrorEventWhenFetchingFails() async throws {
    let collector = QueryStoreEventsCollector<FailingQuery.State>()
    let store = self.client.store(for: FailingQuery())
    let subscription = store.subscribe(with: collector.eventHandler())
    _ = try? await store.tasks.first?.runIfNeeded()
    await Task.megaYield()
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.failure(FailingQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Starts Fetching By When Automatic Fetching Enabled On Subscription")
  func startsFetchingOnSubscriptionWhenAutomaticFetchingEnabled() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .always(true))
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler())
    _ = try await store.tasks.first?.runIfNeeded()
    await Task.megaYield()
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.success(TestQuery.value)),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Emits Nothing When Automatic Fetching Disabled On Subscription")
  func emitsIdleEventWhenAutomaticFetchingEnabled() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler())
    await Task.megaYield()  // NB: Give some time for any potential fetching to start.
    collector.expectEventsMatch([])
    subscription.cancel()
  }

  @Test("Emits Fetch Events When fetch Manually Called")
  func emitsFetchEventsWhenFetchManuallyCalled() async throws {
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler())
    try await store.fetch()
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.success(TestQuery.value)),
      .stateChanged,
      .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Does Not Receive Events When Unsubscribed")
  func doesNotReceiveEventsWhenUnsubscribed() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler())
    subscription.cancel()
    try await store.fetch()
    collector.expectEventsMatch([])
    subscription.cancel()
  }

  @Test("Automatic Fetching Enabled By Default")
  func automaticFetchingEnabledByDefault() async throws {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.isAutomaticFetchingEnabled, true)
  }

  @Test("Automatic Fetching Enabled When Condition Is subscribedTo")
  func automaticFetchingEnabledWhenSubscribedTo() async throws {
    let store = self.client.store(
      for: TestQuery().enableAutomaticFetching(when: .always(true))
    )
    expectNoDifference(store.isAutomaticFetchingEnabled, true)
  }

  @Test("Automatic Fetching Disabled When Condition fetchManuallyCalled")
  func automaticFetchingDisabledWhenFetchManuallyCalled() async throws {
    let store = self.client.store(
      for: TestQuery().enableAutomaticFetching(when: .always(false))
    )
    expectNoDifference(store.isAutomaticFetchingEnabled, false)
  }

  @Test("Handles Events When Fetching")
  func handlesEventsWhenFetching() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .always(false))
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let store = self.client.store(for: query)
    try await store.fetch(handler: collector.eventHandler())
    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.success(TestQuery.value)),
      .stateChanged,
      .fetchingEnded
    ])
  }

  @Test("Does Not Increment Subscription Count When Fetching")
  func doesNotIncrementSubscriptionCountWhenFetching() async throws {
    let clock = TestClock()
    let query = SleepingQuery(clock: clock, duration: .seconds(1))
    let store = self.client.store(for: query)
    query.didBeginSleeping = {
      expectNoDifference(store.subscriberCount, 0)
      Task { await clock.run() }
    }
    try await store.fetch(handler: QueryEventHandler())
  }

  @Test("Cancel Fetch, Query Status Is Cancelled")
  func cancelFetchQueryStatusIsCancelled() async throws {
    let query = SleepingQuery(clock: TestClock(), duration: .seconds(1))
    let store = self.client.store(for: query)
    query.didBeginSleeping = { store.tasks.first?.cancel() }
    _ = try? await store.fetch()
    expectNoDifference(store.status.isCancelled, true)
  }

  @Test("Cancel Fetch From Task, Query Status Is Cancelled")
  func cancelFetchFromTaskQueryStatusIsCancelled() async throws {
    let query = SleepingQuery(clock: TestClock(), duration: .seconds(1))
    let store = self.client.store(for: query)
    let task = Task { try await store.fetch() }
    query.didBeginSleeping = { task.cancel() }
    _ = try? await task.value
    expectNoDifference(store.status.isCancelled, true)
  }

  @Test("Override Query Store Task Name")
  func overrideQueryStoreTaskName() async throws {
    let store = self.client.store(for: TestQuery())
    let config = QueryTaskConfiguration(name: "Blob", context: store.context)
    let taskName = store.fetchTask(using: config).configuration.name
    expectNoDifference(taskName, "Blob")
  }

  @Test("Default Query Store Task Name")
  func defaultQueryStoreTaskName() async throws {
    let store = self.client.store(for: TestQuery())
    let taskName = store.fetchTask().configuration.name
    expectNoDifference(taskName, "QueryStore<QueryState<Int?, Int>> Task")
  }

  @Test("Yields Multiple Values During Query")
  func yieldsMultipleValuesDuringQuery() async throws {
    let query = ContinuingQuery()
    let store = self.client.store(for: query)
    let collector = QueryStoreEventsCollector<ContinuingQuery.State>()
    let value = try await store.fetch(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.success(ContinuingQuery.values[0])),
      .stateChanged,
      .resultReceived(.success(ContinuingQuery.values[1])),
      .stateChanged,
      .resultReceived(.success(ContinuingQuery.values[2])),
      .stateChanged,
      .resultReceived(.success(ContinuingQuery.finalValue)),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, ContinuingQuery.finalValue)
  }

  @Test("Yields Error Then Success During Query")
  func yieldsErrorThenSuccessDuringQuery() async throws {
    let query = ContinuingErrorQuery()
    let store = self.client.store(for: query)
    let collector = QueryStoreEventsCollector<ContinuingErrorQuery.State>()
    let value = try await store.fetch(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.failure(ContinuingErrorQuery.SomeError())),
      .stateChanged,
      .resultReceived(.success(ContinuingErrorQuery.finalValue)),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, ContinuingErrorQuery.finalValue)
    expectNoDifference(
      store.error as? ContinuingErrorQuery.SomeError,
      nil
    )
    expectNoDifference(store.errorLastUpdatedAt != nil, true)
  }

  @Test("Yields Value Then Error During Query")
  func yieldsValueThenErrorDuringQuery() async throws {
    let query = ContinuingValueThenErrorQuery()
    let store = self.client.store(for: query)
    let collector = QueryStoreEventsCollector<ContinuingValueThenErrorQuery.State>()
    let value = try? await store.fetch(handler: collector.eventHandler())

    collector.expectEventsMatch([
      .stateChanged,
      .fetchingStarted,
      .resultReceived(.success(ContinuingValueThenErrorQuery.value)),
      .stateChanged,
      .resultReceived(.failure(ContinuingErrorQuery.SomeError())),
      .stateChanged,
      .fetchingEnded
    ])
    expectNoDifference(value, nil)
    expectNoDifference(
      store.error as? ContinuingValueThenErrorQuery.SomeError,
      ContinuingValueThenErrorQuery.SomeError()
    )
  }

  @Test("Set Current Query Value")
  func setCurrentQueryValue() async throws {
    let store = self.client.store(for: TestQuery())
    store.currentValue = TestQuery.value
    expectNoDifference(store.state.currentValue, TestQuery.value)
  }

  @Test("Set Current Query Value, Emits Event")
  func setCurrentQueryValueEmitsEvent() async throws {
    let store = self.client.store(for: TestQuery())
    store.currentValue = TestQuery.value
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let subscription = store.subscribe(with: collector.eventHandler())
    store.currentValue = TestQuery.value
    collector.expectEventsMatch([.stateChanged])
    subscription.cancel()
  }

  @Test("Reset State, Resets Current Value To Initial Value")
  func resetStateResetsCurrentStateToInitialState() async throws {
    let store = self.client.store(for: TestQuery())
    try await store.fetch()

    expectNoDifference(store.currentValue, TestQuery.value)
    store.reset()
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Reset State, Clears Any Errors")
  func resetStateClearsAnyErrors() async throws {
    let store = self.client.store(for: FailingQuery())
    _ = try? await store.fetch()

    expectNoDifference(store.error as? FailingQuery.SomeError, FailingQuery.SomeError())
    store.reset()
    expectNoDifference(store.error as? FailingQuery.SomeError, nil)
  }

  @Test("Reset State, Resets Value Count")
  func resetStateResetsValueCount() async throws {
    let store = self.client.store(for: TestQuery())
    try await store.fetch()

    expectNoDifference(store.valueUpdateCount, 1)
    store.reset()
    expectNoDifference(store.valueUpdateCount, 0)
  }

  @Test("Reset State, Resets Error Count")
  func resetStateResetsErrorCount() async throws {
    let store = self.client.store(for: FailingQuery())
    _ = try? await store.fetch()

    expectNoDifference(store.errorUpdateCount, 1)
    store.reset()
    expectNoDifference(store.errorUpdateCount, 0)
  }

  @Test("Reset State, Cancels All Active Tasks")
  func resetStateCancelsAllActiveTasks() async throws {
    let store = self.client.store(for: TestQuery())
    let task = store.fetchTask()
    let task2 = store.fetchTask()
    store.reset()
    expectNoDifference(store.tasks, [])
    await #expect(throws: CancellationError.self) {
      try await task.runIfNeeded()
    }
    await #expect(throws: CancellationError.self) {
      try await task2.runIfNeeded()
    }
  }

  @Test("Reset State, Emits Event")
  func resetStateEmitsEvent() async throws {
    let store = self.client.store(for: TestQuery())
    let collector = QueryStoreEventsCollector<TestQuery.State>()
    let subscription = store.subscribe(with: collector.eventHandler())
    store.reset()
    collector.expectEventsMatch([.stateChanged])
    subscription.cancel()
  }
}

extension QueryContext {
  fileprivate var test: String {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }

  private struct TestKey: Key {
    static let defaultValue = "test"
  }
}
