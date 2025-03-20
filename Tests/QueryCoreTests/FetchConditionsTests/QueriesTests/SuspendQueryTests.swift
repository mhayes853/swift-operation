import CustomDump
import QueryCore
import Testing

@Suite("SuspendQuery tests")
struct SuspendQueryTests {
  @Test("Condition True When Query Starts, Runs Query Immediately")
  func conditionTrueWhenQueryStartsRunsQueryImmediately() async throws {
    let query = TestQuery().suspend(on: .always(true))
    let store = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)
    let value = try await store.fetch()
    expectNoDifference(value, TestQuery.value)
  }

  @Test("Condition False When Query Starts, Waits Until Condition Is True To Run The Query")
  func conditionFalseWhenQueryStartsWaitsUntilConditionIsTrueToRunTheQuery() async throws {
    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().suspend(on: condition)
    let store = QueryStoreFor<TestQuery>.detached(query: query, initialValue: nil)
    let task = Task { try await store.fetch() }
    await Task.megaYield()
    expectNoDifference(store.isLoading, true)
    condition.send(true)
    let value = try await task.value
    expectNoDifference(value, TestQuery.value)
    expectNoDifference(store.isLoading, false)
  }
}
