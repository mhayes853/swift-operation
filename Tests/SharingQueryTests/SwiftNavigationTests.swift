#if SwiftNavigation
  import SwiftNavigation
  import XCTest
  import SharingQuery
  import CustomDump
  import QueryTestHelpers

  @MainActor
  final class SwiftNavigationTests: XCTestCase {
    func testAppliesTransactionWhenSettingValue() async throws {
      let expectation = self.expectation(description: "observes value")
      expectation.expectedFulfillmentCount = 4

      let values = Lock([Int]())

      let query = TestQuery().enableAutomaticFetching(onlyWhen: .always(false))
      var transaction = UITransaction()
      transaction[TestKey.self] = 10
      @SharedQuery(query, transaction: transaction) var state

      let token = observe { transaction in
        _ = state
        expectation.fulfill()
        values.withLock { $0.append(transaction[TestKey.self]) }
      }

      try await $state.fetch()
      await self.fulfillment(of: [expectation])

      // NB: 0 comes from running the observe block initially where no transaction is applied to
      // the initial query value.
      values.withLock { expectNoDifference($0, [0, 10, 10, 10]) }
      token.cancel()
    }
  }

  private enum TestKey: UITransactionKey {
    static let defaultValue = 0
  }
#endif
