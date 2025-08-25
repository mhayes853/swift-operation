import CustomDump
import Foundation
import SharingOperation
import Testing

@testable import CaseStudies

@Suite("RefetchOnNotification tests")
struct RefetchOnNotificationTests {
  @Test("Refetches When Notification Posted")
  func refetchesWhenNotificationPosted() async throws {
    let center = NotificationCenter()
    @SharedOperation(TestQuery().refetchOnPost(of: .fake, center: center)) var num

    _ = try await $num.activeTasks.first?.runIfNeeded()

    center.post(name: .fake, object: nil)

    _ = try await $num.activeTasks.first?.runIfNeeded()

    expectNoDifference($num.valueUpdateCount, 2)
  }
}

private struct TestQuery: QueryRequest, Hashable {
  func fetch(
    in context: OperationContext,
    with continuation: OperationContinuation<Int>
  ) async throws -> Int {
    0
  }
}

extension Notification.Name {
  fileprivate static let fake = Self(rawValue: "FakeNotification")
}
