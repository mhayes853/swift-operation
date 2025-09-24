import CanIClimbKit
import CustomDump
import Operation
import Testing

@Suite("QueryStore+ResetWaitingForAllActiveTasksToFinish tests")
struct QueryStoreResetWaitingForAllActiveTasksToFinishTests {
  @Test("Resets State")
  func resetsState() async throws {
    let store = OperationStore.detached(query: CountingQuery(), initialValue: nil)
    await store.fetch()
    await store.resetWaitingForAllActiveTasksToFinish()
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Never Deduplicates On Going Cancelled Fetches After Waiting")
  func neverDeduplicatesOnGoingCancelledFetchesAfterWaiting() async throws {
    for _ in 0..<100 {
      let store = OperationStore.detached(query: CountingQuery().deduplicated(), initialValue: nil)
      let task = Task.immediate { await store.fetch() }
      await store.resetWaitingForAllActiveTasksToFinish()
      let value = await store.fetch()
      let taskValue = await task.value
      if value == taskValue {
        Issue.record("Should Not Deduplicate. Received \(value).")
        break
      }
    }
  }

  @Test("Never Fetches Unstarted Task On Reset State")
  func neverFetchesUnstartedTaskOnResetState() async throws {
    let store = OperationStore.detached(query: CountingQuery().deduplicated(), initialValue: nil)
    _ = store.fetchTask()
    await store.resetWaitingForAllActiveTasksToFinish()
    let value = await store.fetch()
    expectNoDifference(value, 1)
  }
}

private final actor CountingQuery: QueryRequest, Identifiable {
  private var count = 0

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, Never>
  ) async -> Int {
    await Task.yield()
    return await isolate(self) {
      $0.count += 1
      return $0.count
    }
  }
}
