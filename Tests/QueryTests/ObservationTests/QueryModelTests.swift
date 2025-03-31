import CustomDump
import Query
import SwiftNavigation
import Testing
import _TestQueries

@MainActor
@Suite("QueryModel tests")
struct QueryModelTests {
  private let client = QueryClient()

  @Test("InitialState Is Current State")
  func initialStateIsCurrentState() {
    let model = self.client.model(
      for: TestQuery().enableAutomaticFetching(when: .always(false)).defaultValue(TestQuery.value)
    )
    expectNoDifference(model.currentValue, TestQuery.value)
  }

  @Test("Subscribes To Query On Init")
  func subscribesToQueryOnInit() async throws {
    let model = self.client.model(for: TestQuery())
    _ = try? await model.activeTasks.first?.runIfNeeded()
    await Task.megaYield()
    expectNoDifference(model.currentValue, TestQuery.value)
  }

  @Test("Subscribes To Query State Updates")
  func subscribesToQueryStateUpdates() async throws {
    let model = self.client.model(for: TestQuery().enableAutomaticFetching(when: .always(false)))
    try await model.fetch()
    await Task.megaYield()
    expectNoDifference(model.currentValue, TestQuery.value)
  }
}
