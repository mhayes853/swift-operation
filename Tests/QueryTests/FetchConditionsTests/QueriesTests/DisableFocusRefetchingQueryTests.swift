import CustomDump
import Foundation
import Query
import Testing
import _TestQueries

@Suite("DisableFocusRefetchingQuery tests")
struct DisableFocusRefetchingQueryTests {
  private let center = NotificationCenter()

  @Test("Does Not Refetch Query On Focus")
  func doesNotRefetchQueryOnFocus() async throws {
    let automaticCondition = TestCondition()
    automaticCondition.send(false)

    let query = TestQuery().disableFocusRefetching()
      .enableAutomaticFetching(onlyWhen: automaticCondition)
      .refetchOnChange(
        of: .notificationFocus(
          didBecomeActive: .fakeDidBecomeActive,
          willResignActive: .fakeWillResignActive,
          center: self.center,
          isActive: { @Sendable in false }
        )
      )
    let store = QueryStore.detached(query: query, initialValue: nil)
    let subscription = store.subscribe(with: QueryEventHandler())
    automaticCondition.send(true)

    self.center.post(name: .fakeDidBecomeActive, object: nil)
    await Task.megaYield()

    expectNoDifference(store.currentValue, nil)

    subscription.cancel()
  }
}
