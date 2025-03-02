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

  @Test("Deduplicates Fetches From The Same Store")
  func deduplicatesFetchesSameStore() async throws {
    let query = CountingQuery()
    let store = self.client.store(for: query)
    async let f1 = store.fetch()
    async let f2 = store.fetch()
    _ = try await (f1, f2)
    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Deduplicates Fetches From Different Stores")
  func deduplicatesFetchesDifferentStores() async throws {
    let query = CountingQuery()
    let store = self.client.store(for: query)
    let store2 = self.client.store(for: query)
    async let f1 = store.fetch()
    async let f2 = store2.fetch()
    _ = try await (f1, f2)
    let count = await query.fetchCount
    expectNoDifference(count, 1)
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
    let collector = QueryStoreEventsCollector<TestQuery.Value>()
    let store = self.client.store(for: TestQuery())
    let subscription = store.subscribe(with: collector.eventHandler)
    try await store.fetch()
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.success(TestQuery.value)), .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Only Starts Fetching For The First Query Subscriber")
  func startsFetchingOnFirstSubscription() async throws {
    let query = CountingQuery {}
    let store = self.client.store(for: query)
    let s1 = store.subscribe(with: QueryEventHandler())
    try await store.fetch()
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
    let collector = QueryStoreEventsCollector<FailingQuery.Value>()
    let store = self.client.store(for: FailingQuery())
    var subscription = store.subscribe(with: collector.eventHandler)
    _ = try? await store.fetch()
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.failure(FailingQuery.SomeError())), .fetchingEnded
    ])
    subscription.cancel()
    collector.reset()
    subscription = store.subscribe(with: collector.eventHandler)
    _ = try? await store.fetch()
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.failure(FailingQuery.SomeError())), .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Emits Error Event When Fetching Fails")
  func emitsErrorEventWhenFetchingFails() async throws {
    let collector = QueryStoreEventsCollector<FailingQuery.Value>()
    let store = self.client.store(for: FailingQuery())
    let subscription = store.subscribe(with: collector.eventHandler)
    _ = try? await store.fetch()
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.failure(FailingQuery.SomeError())), .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Starts Fetching By When Automatic Fetching Enabled On Subscription")
  func startsFetchingOnSubscriptionWhenAutomaticFetchingEnabled() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .firstSubscribedTo)
    let collector = QueryStoreEventsCollector<TestQuery.Value>()
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler)
    try await store.fetch()
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.success(TestQuery.value)), .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Emits Nothing When Automatic Fetching Disabled On Subscription")
  func emitsIdleEventWhenAutomaticFetchingEnabled() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .fetchManuallyCalled)
    let collector = QueryStoreEventsCollector<TestQuery.Value>()
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler)
    await Task.megaYield()  // NB: Give some time for any potential fetching to start.
    collector.expectEventsMatch([])
    subscription.cancel()
  }

  @Test("Emits Fetch Events When fetch Manually Called")
  func emitsFetchEventsWhenFetchManuallyCalled() async throws {
    let collector = QueryStoreEventsCollector<TestQuery.Value>()
    let query = TestQuery().enableAutomaticFetching(when: .fetchManuallyCalled)
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler)
    try await store.fetch()
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.success(TestQuery.value)), .fetchingEnded
    ])
    subscription.cancel()
  }

  @Test("Does Not Receive Events When Unsubscribed")
  func doesNotReceiveEventsWhenUnsubscribed() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .fetchManuallyCalled)
    let collector = QueryStoreEventsCollector<TestQuery.Value>()
    let store = self.client.store(for: query)
    let subscription = store.subscribe(with: collector.eventHandler)
    subscription.cancel()
    try await store.fetch()
    collector.expectEventsMatch([])
    subscription.cancel()
  }

  @Test("Automatic Fetching Enabled By Default")
  func automaticFetchingEnabledByDefault() async throws {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.willFetchOnFirstSubscription, true)
  }

  @Test("Automatic Fetching Enabled When Condition Is subscribedTo")
  func automaticFetchingEnabledWhenSubscribedTo() async throws {
    let store = self.client.store(
      for: TestQuery().enableAutomaticFetching(when: .firstSubscribedTo)
    )
    expectNoDifference(store.willFetchOnFirstSubscription, true)
  }

  @Test("Automatic Fetching Disabled When Condition fetchManuallyCalled")
  func automaticFetchingDisabledWhenFetchManuallyCalled() async throws {
    let store = self.client.store(
      for: TestQuery().enableAutomaticFetching(when: .fetchManuallyCalled)
    )
    expectNoDifference(store.willFetchOnFirstSubscription, false)
  }

  @Test("Handles Events When Fetching")
  func handlesEventsWhenFetching() async throws {
    let query = TestQuery().enableAutomaticFetching(when: .fetchManuallyCalled)
    let collector = QueryStoreEventsCollector<TestQuery.Value>()
    let store = self.client.store(for: query)
    try await store.fetch(handler: collector.eventHandler)
    collector.expectEventsMatch([
      .fetchingStarted, .resultReceived(.success(TestQuery.value)), .fetchingEnded
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

  @Test("Init Casting Returns Nil When Invalid Cast")
  func initCastingReturnsNilWhenInvalidCast() async throws {
    let store1 = AnyQueryStore.detached(erasing: TestQuery().defaultValue(TestQuery.value))
    let store2 = QueryStoreFor<TestStringQuery>(casting: store1)
    expectNoDifference(store2 == nil, true)
  }

  @Test("Init Casting Returns New Store When Valid Cast")
  func initCastingReturnsNewStoreWhenValidCast() async throws {
    let store1 = AnyQueryStore.detached(
      erasing: TestStringQuery().defaultValue(TestStringQuery.value)
    )
    let store2 = QueryStoreFor<DefaultQuery<TestStringQuery>>(casting: store1)
    expectNoDifference(store2 != nil, true)
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
