#if SwiftOperationNavigation
  import SwiftNavigation
  import XCTest
  import SharingOperation
  import CustomDump
  import OperationTestHelpers

  @MainActor
  final class SwiftNavigationTests: XCTestCase, @unchecked Sendable {
    func testAppliesTransactionWhenSettingValue() async throws {
      let expectation = self.expectation(description: "observes value")
      expectation.assertForOverFulfill = false

      let query = TestQuery().disableAutomaticFetching()
      var transaction = UITransaction()
      transaction[TestKey.self] = 10
      @SharedOperation(query, transaction: transaction) var state

      let token = observe { transaction in
        _ = state
        if transaction[TestKey.self] == 10 {
          expectation.fulfill()
        }
      }

      try await $state.fetch()
      await self.fulfillment(of: [expectation], timeout: 0.1)

      token.cancel()
    }
  }

  private enum TestKey: UITransactionKey {
    static let defaultValue = 0
  }
#endif
