@testable import CaseStudies
import SharingQuery
import Foundation
import Testing
import CustomDump

@Suite("RefetchOnNotification tests")
struct RefetchOnNotificationTests {
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
    print("fetched")
    return 0
  }
}

extension Notification.Name {
  fileprivate static let fake = Self(rawValue: "FakeNotification")
}
