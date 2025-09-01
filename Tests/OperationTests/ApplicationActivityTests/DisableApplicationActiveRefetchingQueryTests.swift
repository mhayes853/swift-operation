import CustomDump
import Foundation
import Operation
import OperationTestHelpers
import XCTest

@MainActor
final class DisableApplicationActiveRefetchingQueryTests: XCTestCase, @unchecked Sendable {
  private let center = NotificationCenter()

  func testDoesNotRefetchQueryOnFocus() async throws {
    let observer = TestApplicationActivityObserver()
    let expectation = self.expectation(description: "starts fetching")
    expectation.isInverted = true

    let automaticCondition = TestRunSpecification()
    automaticCondition.send(false)
    let query = TestQuery().disableApplicationActiveRerunning()
      .enableAutomaticRunning(onlyWhen: automaticCondition)
      .rerunOnChange(of: .applicationIsActive(observer: observer))
    let store = OperationStore.detached(query: query, initialValue: nil)
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in expectation.fulfill() })
    )
    automaticCondition.send(true)

    observer.send(isActive: true)
    await self.fulfillment(of: [expectation], timeout: 0.05)

    subscription.cancel()
  }
}
