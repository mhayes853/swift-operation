import CustomDump
import Foundation
@_spi(ApplicationActivityObserver) import Query
import QueryTestHelpers
import XCTest

@MainActor
final class DisableApplicationActiveRefetchingQueryTests: XCTestCase, @unchecked Sendable {
  private let center = NotificationCenter()

  func testDoesNotRefetchQueryOnFocus() async throws {
    let observer = TestDarwinApplicationActivityObserver(
      isInitiallyActive: false,
      notificationCenter: self.center
    )
    let expectation = self.expectation(description: "starts fetching")
    expectation.isInverted = true

    let automaticCondition = TestCondition()
    automaticCondition.send(false)
    let query = TestQuery().disableApplicationActiveRefetching()
      .enableAutomaticFetching(onlyWhen: automaticCondition)
      .refetchOnChange(of: .applicationIsActive(observer: observer))
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
