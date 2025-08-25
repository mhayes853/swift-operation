import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import SharingOperation
import SwiftNavigation
import Synchronization
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("AlertStateQuery tests")
  struct AlertStateQueryTests {
    @Test(
      "Posts Alert When Query Finished",
      arguments: [(false, AlertState<Never>.success), (true, .failure)]
    )
    func postsSuccessAlertWhenQuerySucceeds(
      shouldFail: Bool,
      alert: AlertState<Never>
    ) async throws {
      @Dependency(\.notificationCenter) var center

      let store = OperationStore.detached(
        query: TestQuery(shouldFail: shouldFail).alerts(success: .success, failure: .failure),
        initialValue: nil
      )
      await confirmation { confirm in
        let token = center.addObserver(for: OperationAlertMessage.self) { message in
          expectNoDifference(message.alert, alert)
          confirm()
        }
        _ = try? await store.fetch()
        center.removeObserver(token)
      }
    }

    @Test("Only Posts Failure Alert Once When Retried")
    func onlyPostsFailureAlertOnceWhenRetried() async throws {
      @Dependency(\.notificationCenter) var center

      let store = OperationStore.detached(
        query: TestQuery(shouldFail: true).alerts(success: .success, failure: .failure)
          .delayer(.noDelay)
          .retry(limit: 3),
        initialValue: nil
      )
      await confirmation(expectedCount: 1) { confirm in
        let token = center.addObserver(for: OperationAlertMessage.self) { _ in
          confirm()
        }
        _ = try? await store.fetch()
        center.removeObserver(token)
      }
    }
  }
}

extension AlertState where Action == Never {
  fileprivate static let success = Self { TextState("Success") }
  fileprivate static let failure = Self { TextState("Failure") }
}

private struct TestQuery: QueryRequest, Hashable {
  let shouldFail: Bool
  func fetch(
    in context: OperationContext,
    with continuation: OperationContinuation<Int>
  ) async throws -> Int {
    if self.shouldFail {
      struct SomeError: Error {}
      throw SomeError()
    } else {
      return 0
    }
  }
}
