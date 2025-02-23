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
    expectNoDifference(store.value, defaultValue)
  }

  @Test("Store Has Nil Value Initially")
  func hasNilValue() {
    let store = self.client.store(for: TestQuery())
    expectNoDifference(store.value, nil)
  }

  @Test("Has Fetched Value After Fetching")
  func fetchedValue() async throws {
    let store = self.client.store(for: TestQuery())
    let value = try await store.fetch()
    expectNoDifference(value, TestQuery.value)
    expectNoDifference(store.value, TestQuery.value)
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
    expectNoDifference(store.value, nil)
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
}
