import CustomDump
import Query
import QueryTestHelpers
import Testing

@Suite("QueryStore+AsyncSequences tests")
struct QueryStoreAsyncSequencesTests {
  private let client = QueryClient()

  @Test("Emits State Updates From Sequence")
  func emitsStateUpdatesFromSequence() async throws {
    let store = self.client.store(for: TestQuery())
    let task = Task {
      await store.states.prefix(3).reduce(into: [TestQuery.State]()) { $0.append($1.state) }
    }
    await Task.megaYield()
    _ = try? await store.activeTasks.first?.runIfNeeded()
    let value = await task.value
    expectNoDifference(value.count, 3)
    expectNoDifference(value[0].status.isIdle, true)
    expectNoDifference(value[1].isLoading, true)
    expectNoDifference(value[2].currentValue, TestQuery.value)
  }
}
