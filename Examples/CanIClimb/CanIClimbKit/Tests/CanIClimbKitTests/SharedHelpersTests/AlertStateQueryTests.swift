import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import SharingQuery
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

      let store = QueryStore.detached(
        query: TestQuery(shouldFail: shouldFail).alerts(success: .success, failure: .failure),
        initialValue: nil
      )
      let (stream, continuation) = AsyncStream<Void>.makeStream()
      var iter = stream.makeAsyncIterator()
      let token = center.addObserver(for: QueryAlertMessage.self) { message in
        expectNoDifference(message.alert, alert)
        continuation.yield()
      }
      _ = try? await store.fetch()
      await iter.next()
      center.removeObserver(token)
    }

    @Test("Only Posts Failure Alert Once When Retried")
    func onlyPostsFailureAlertOnceWhenRetried() async throws {
      @Dependency(\.notificationCenter) var center

      let store = QueryStore.detached(
        query: TestQuery(shouldFail: true).alerts(success: .success, failure: .failure)
          .retry(limit: 3, delayer: .noDelay),
        initialValue: nil
      )
      let (stream, continuation) = AsyncStream<Void>.makeStream()
      let token = center.addObserver(for: QueryAlertMessage.self) { message in
        expectNoDifference(message.alert, .failure)
        continuation.yield()
      }
      _ = try? await store.fetch()
      // NB: Give time for the observer to spin up a task with the alert.
      try await Task.sleep(for: .milliseconds(100))
      continuation.finish()

      var count = 0
      for await _ in stream {
        count += 1
      }
      expectNoDifference(count, 1)
      center.removeObserver(token)
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
    in context: QueryContext,
    with continuation: QueryContinuation<Int>
  ) async throws -> Int {
    if self.shouldFail {
      struct SomeError: Error {}
      throw SomeError()
    } else {
      return 0
    }
  }
}
