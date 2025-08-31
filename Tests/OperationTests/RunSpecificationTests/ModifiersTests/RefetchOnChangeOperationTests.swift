import CustomDump
import Operation
import OperationTestHelpers
import XCTest

final class RefetchOnChangeOperationTests: XCTestCase {
  func testRefetchesWhenConditionChangesToTrue() async {
    let fetchesExpectation = self.expectation(description: "begins fetching")

    let condition = TestRunSpecification()
    condition.send(false)

    let automaticCondition = TestRunSpecification()
    automaticCondition.send(false)
    let store = OperationStore.detached(
      query: TestQuery().enableAutomaticRunning(onlyWhen: automaticCondition)
        .reRunOnChange(of: condition),
      initialValue: nil
    )
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in fetchesExpectation.fulfill() })
    )
    automaticCondition.send(true)

    condition.send(true)
    await self.fulfillment(of: [fetchesExpectation], timeout: 0.05)

    subscription.cancel()
  }

  func testCancelsInProgressRefetchWhenRefetched() async {
    let fetchesExpectation = self.expectation(description: "begins fetching")
    let cancelsExpectation = self.expectation(description: "cancels")

    let condition = TestRunSpecification()
    condition.send(false)

    let count = Lock(0)
    let automaticCondition = TestRunSpecification()
    automaticCondition.send(false)
    let store = OperationStore.detached(
      query: CountingQuery {
        let c = count.withLock { count in
          count += 1
          return count
        }
        if c == 1 {
          try await Task.never()
        }
      }
      .enableAutomaticRunning(onlyWhen: automaticCondition)
      .reRunOnChange(of: condition),
      initialValue: nil
    )
    let subscription = store.subscribe(
      with: QueryEventHandler(
        onFetchingStarted: { _ in
          expectNoDifference(store.status.isCancelled, false)
          fetchesExpectation.fulfill()
        },
        onFetchingEnded: { _ in
          expectNoDifference(store.status.isCancelled, true)
          cancelsExpectation.fulfill()
        }
      )
    )
    automaticCondition.send(true)

    condition.send(true)
    await self.fulfillment(of: [fetchesExpectation], timeout: 0.05)

    condition.send(false)
    await self.fulfillment(of: [cancelsExpectation], timeout: 0.05)

    subscription.cancel()
  }

  func testDoesNotRefetchWhenConditionChangesToFalse() async {
    let expectation = self.expectation(description: "fetches")
    expectation.isInverted = true

    let condition = TestRunSpecification()
    condition.send(true)

    let automaticCondition = TestRunSpecification()
    automaticCondition.send(false)
    let store = OperationStore.detached(
      query: TestQuery().enableAutomaticRunning(onlyWhen: automaticCondition)
        .reRunOnChange(of: condition),
      initialValue: nil
    )
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in expectation.fulfill() })
    )
    automaticCondition.send(true)

    condition.send(false)
    await self.fulfillment(of: [expectation], timeout: 0.05)

    subscription.cancel()
  }

  func testDoesNotRefetchWhenNoSubscribersOnOperationStore() async {
    let expectation = self.expectation(description: "fetches")
    expectation.isInverted = true

    let condition = TestRunSpecification()
    condition.send(false)

    let query = CountingQuery { expectation.fulfill() }
    let store = OperationStore.detached(
      query: query.enableAutomaticRunning(onlyWhen: .always(true)).reRunOnChange(of: condition),
      initialValue: nil
    )

    condition.send(true)
    await self.fulfillment(of: [expectation], timeout: 0.05)

    _ = store
  }

  func testDoesNotRefetchWhenQueryIsNotStale() async {
    let expectation = self.expectation(description: "fetches")
    expectation.isInverted = true

    let condition = TestRunSpecification()
    condition.send(false)

    let automaticCondition = TestRunSpecification()
    automaticCondition.send(false)
    let store = OperationStore.detached(
      query: TestQuery().enableAutomaticRunning(onlyWhen: automaticCondition)
        .reRunOnChange(of: condition)
        .staleWhen { _, _ in false },
      initialValue: nil
    )
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in expectation.fulfill() })
    )
    automaticCondition.send(true)

    condition.send(true)
    await self.fulfillment(of: [expectation], timeout: 0.05)

    subscription.cancel()
  }
}
