import CanIClimbKit
import CustomDump
import Dependencies
import SharingGRDB
import SharingQuery
import Synchronization
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("Mountain+Detail tests")
  struct MountainDetailTests {
    @Test("Caches Mountain After Fetching")
    func cachesMountainAfterFetching() async throws {
      let loader = Mountain.MockLoader(result: .success(.mock1))
      try await withDependencies {
        $0[Mountain.LoaderKey.self] = loader
      } operation: {
        let mountains = Mutex([Mountain?]())
        let handler = QueryEventHandler<Mountain.Query.State>(
          onResultReceived: { r, _ in mountains.withLock { $0.append(try? r.get()) } }
        )
        let store = QueryStore.detached(
          query: Mountain.query(id: Mountain.mock1.id),
          initialValue: nil
        )
        try await store.fetch(handler: handler)

        mountains.withLock {
          expectNoDifference($0, [.mock1])
          $0.removeAll()
        }

        var mock2 = Mountain.mock1
        mock2.name = "Updated"

        loader.result = .success(mock2)
        try await store.fetch(handler: handler)
        mountains.withLock { expectNoDifference($0, [.mock1, mock2]) }
      }
    }

    @Test("Deletes Cached Mountain When Nil Returned")
    func deletesCachedMountainWhenNilReturned() async throws {
      let loader = Mountain.MockLoader(result: .success(.mock1))
      try await withDependencies {
        $0[Mountain.LoaderKey.self] = loader
      } operation: {
        let store = QueryStore.detached(
          query: Mountain.query(id: Mountain.mock1.id),
          initialValue: nil
        )
        try await store.fetch()

        loader.result = .success(nil)
        try await store.fetch()

        try await confirmation(expectedCount: 0) { confirm in
          let handler = QueryEventHandler<Mountain.Query.State>(
            onResultReceived: { _, context in
              guard context.queryResultUpdateReason == .yieldedResult else { return }
              confirm()
            }
          )
          loader.result = .success(.mock1)
          try await store.fetch(handler: handler)
        }
      }
    }
  }
}
