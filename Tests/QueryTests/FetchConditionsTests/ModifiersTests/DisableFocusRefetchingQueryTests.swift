import CustomDump
import Foundation
import Query
import QueryTestHelpers
import XCTest

final class DisableFocusRefetchingQueryTests: XCTestCase {
  private let center = NotificationCenter()

  func testDoesNotRefetchQueryOnFocus() async throws {
    let expectation = self.expectation(description: "starts fetching")
    expectation.isInverted = true

    let automaticCondition = TestCondition()
    automaticCondition.send(false)
    let query = TestQuery().disableFocusRefetching()
      .enableAutomaticFetching(onlyWhen: automaticCondition)
      .refetchOnChange(
        of: .applicationIsActive(
          didBecomeActive: .fakeDidBecomeActive,
          willResignActive: .fakeWillResignActive,
          center: self.center,
          isActive: { @Sendable in false }
        )
      )
    let store = QueryStore.detached(query: query, initialValue: nil)
    let subscription = store.subscribe(
      with: QueryEventHandler(onFetchingStarted: { _ in expectation.fulfill() })
    )
    automaticCondition.send(true)

    self.center.post(name: .fakeDidBecomeActive, object: nil)
    await self.fulfillment(of: [expectation], timeout: 0.05)

    subscription.cancel()
  }
}
