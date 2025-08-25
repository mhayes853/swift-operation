import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("OperationStore+AsyncSequences tests")
struct OperationStoreAsyncSequencesTests {
  private let client = OperationClient()

  @Test("Emits State Updates From Sequence")
  func emitsStateUpdatesFromSequence() async throws {
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    var subIter = substream.makeAsyncIterator()

    let store = self.client.store(for: TestQuery())
    let task = Task {
      await store.states.prefix(3)
        .reduce(into: [TestQuery.State]()) {
          $0.append($1.state)
          subcontinuation.yield()
        }
    }
    await subIter.next()
    _ = try? await store.activeTasks.first?.runIfNeeded()
    let value = await task.value
    expectNoDifference(value.count, 3)
    expectNoDifference(value[0].status.isIdle, true)
    expectNoDifference(value[1].isLoading, true)
    expectNoDifference(value[2].currentValue, TestQuery.value)
  }
}
