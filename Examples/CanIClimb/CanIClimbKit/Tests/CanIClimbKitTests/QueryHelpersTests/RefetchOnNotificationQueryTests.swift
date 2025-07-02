import CanIClimbKit
import CustomDump
import Foundation
import SharingQuery
import Testing

@Suite("RefetchOnNotificationQuery tests")
struct RefetchOnNotificationQueryTests {
  @Test("Refetches When Notification Posted")
  func refetchesWhenNotificationPosted() async throws {
    let center = NotificationCenter()
    @SharedQuery(TestQuery().refetchOnPost(of: .fake, center: center)) var num

    _ = try await $num.activeTasks.first?.runIfNeeded()

    center.post(name: .fake, object: nil)

    _ = try await $num.activeTasks.first?.runIfNeeded()

    expectNoDifference($num.valueUpdateCount, 2)
  }
}

private struct TestQuery: QueryRequest, Hashable {
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    0
  }
}

extension Notification.Name {
  fileprivate static let fake = Self(rawValue: "FakeNotification")
}
