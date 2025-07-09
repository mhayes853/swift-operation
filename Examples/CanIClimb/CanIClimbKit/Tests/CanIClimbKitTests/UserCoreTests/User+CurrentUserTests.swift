import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Foundation
import Query
import SharingGRDB
import Synchronization
import Testing

extension DependenciesTestSuite {
  @Suite("User+CurrentUser tests")
  struct UserCurrentUserTests {
    @MainActor
    @Test("Caches Current User In Database")
    func savesCurrentUserInDatabase() async throws {
      let loader = User.MockCurrentLoader(result: .success(.mock1))
      try await withDependencies {
        $0[User.CurrentLoaderKey.self] = loader
      } operation: {
        let users = Mutex([User?]())
        let handler = QueryEventHandler<User.CurrentQuery.State>(
          onResultReceived: { r, _ in users.withLock { $0.append(try? r.get()) } }
        )
        let store = QueryStore.detached(query: User.currentQuery, initialValue: nil)
        try await store.fetch(handler: handler)

        users.withLock {
          expectNoDifference($0, [.mock1])
          $0.removeAll()
        }

        loader.result = .success(.mock2)
        try await store.fetch(handler: handler)
        users.withLock { expectNoDifference($0, [.mock1, .mock2]) }
      }
    }
  }
}
