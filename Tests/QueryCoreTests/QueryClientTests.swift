import CustomDump
import IssueReporting
import QueryCore
import Testing

@Suite("QueryClient tests")
struct QueryClientTests {
  @Test("Maintains The Same Query State For Multiple Stores With The Same Query")
  func maintainsValueForMultipleStores() async throws {
    let client = QueryClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1.value, store2.value)
    expectNoDifference(store2.value, TestQuery.value)
  }

  @Test("Reports Issue When Different Query Type Has The Same Path As Another Query")
  func cannotHaveDuplicatePaths() async throws {
    let client = QueryClient()
    _ = client.store(for: TestQuery())
    withExpectedIssue {
      _ = client.store(for: TestQuery().defaultValue(TestQuery.value + 10))
    }
  }

  @Test("Does Not Share States Between Different Queries")
  func doesNotShareStateBetweenDifferentQueries() async throws {
    let client = QueryClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestStringQuery().defaultValue("bar"))

    expectNoDifference(store1.value, TestQuery.value)
    expectNoDifference(store2.value, "bar")
  }
}
