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
}
