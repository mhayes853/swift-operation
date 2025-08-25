import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("SuspendQuery tests")
struct SuspendQueryTests {
  @Test("Condition True When Query Starts, Runs Query Immediately")
  func conditionTrueWhenQueryStartsRunsQueryImmediately() async throws {
    let query = TestQuery().suspend(on: .always(true))
    let store = OperationStore.detached(query: query, initialValue: nil)
    let value = try await store.fetch()
    expectNoDifference(value, TestQuery.value)
  }

  @Test("Condition False When Query Starts, Waits Until Condition Is True To Run The Query")
  func conditionFalseWhenQueryStartsWaitsUntilConditionIsTrueToRunTheQuery() async throws {
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    var subIter = substream.makeAsyncIterator()

    let condition = TestCondition()
    condition.send(false)

    let query = TestQuery().disableAutomaticFetching().suspend(on: condition)
    let store = OperationStore.detached(query: query, initialValue: nil)
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in subcontinuation.yield() })
    )

    let task = Task { try await store.fetch() }
    await subIter.next()
    expectNoDifference(store.isLoading, true)

    condition.send(true)
    let value = try await task.value
    expectNoDifference(value, TestQuery.value)
    expectNoDifference(store.isLoading, false)

    subscription.cancel()
  }

  @Test("Condition False When Query Starts, Unsubscribes After Condition Is True")
  func conditionFalseWhenQueryStartsUnsubscribesAfterConditionIsTrue() async throws {
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    var subIter = substream.makeAsyncIterator()

    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().disableAutomaticFetching().suspend(on: condition)
    let store = OperationStore.detached(query: query, initialValue: nil)
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in subcontinuation.yield() })
    )

    let task = Task { try await store.fetch() }
    await subIter.next()
    expectNoDifference(condition.subscriberCount, 1)

    condition.send(true)
    _ = try await task.value
    expectNoDifference(condition.subscriberCount, 0)

    subscription.cancel()
  }

  @Test(
    "Condition False When Query Starts, Condition Signals True Twice In a Row Quickly, Does Not Crash"
  )
  func conditionFalseWhenQueryStartsConditionSignalsTrueTwiceInARowQuicklyDoesNotCrash()
    async throws
  {
    let (substream, subcontinuation) = AsyncStream<Void>.makeStream()
    var subIter = substream.makeAsyncIterator()

    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().disableAutomaticFetching().suspend(on: condition)
    let store = OperationStore.detached(query: query, initialValue: nil)
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in subcontinuation.yield() })
    )

    let task = Task { try await store.fetch() }
    await subIter.next()
    expectNoDifference(condition.subscriberCount, 1)

    condition.send(true)
    condition.send(true)
    let value = try await task.value
    expectNoDifference(value, TestQuery.value)

    subscription.cancel()
  }

  @Test("Cancellation While Suspended")
  func cancellationWhileSuspended() async throws {
    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().suspend(on: .always(false))
    let store = OperationStore.detached(query: query, initialValue: nil)

    let task = Task { try await store.fetch() }
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    expectNoDifference(store.status.isCancelled, true)
  }

  @Test("Cancellation While Suspended, Unsubscribes From Condition")
  func cancellationWhileSuspendedUnsubscribesFromCondition() async throws {
    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().suspend(on: condition)
    let store = OperationStore.detached(query: query, initialValue: nil)

    let task = Task { try await store.fetch() }
    task.cancel()
    _ = try? await task.value
    expectNoDifference(condition.subscriberCount, 0)
  }

  @Test("Cancellation While Suspended, Does Not Crash When Sending True After Cancel")
  func cancellationWhileSuspendedDoesNotCrashWhenSendingTrueAfterCancel() async throws {
    let condition = TestCondition()
    condition.send(false)
    let query = TestQuery().suspend(on: condition)
    let store = OperationStore.detached(query: query, initialValue: nil)

    let task = Task { try await store.fetch() }
    task.cancel()
    condition.send(true)
    _ = try? await task.value
    expectNoDifference(condition.subscriberCount, 0)
  }
}
