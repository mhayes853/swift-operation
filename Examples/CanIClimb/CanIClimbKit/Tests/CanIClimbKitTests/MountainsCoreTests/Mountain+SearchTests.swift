import CanIClimbKit
import CustomDump
import Dependencies
import SharingQuery
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("Mountain+Search tests")
  struct MountainSearchTests {
    @Test("Seeds Query Client With Detail Results After Page Fetch")
    func seedsQueryClientWithDetailResults() async throws {
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[0] = .success(
          Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
        )
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let searchStore = client.store(for: Mountain.searchQuery(.recommended))

        try await searchStore.fetchNextPage()

        let mountainStore = client.store(for: Mountain.query(id: Mountain.mock1.id))
        expectNoDifference(mountainStore.currentValue, .mock1)
      }
    }

    @Test("Seeds Query Client With Prexisting Detail Results After Page Fetch")
    func seedsQueryClientWithPreExistingDetailResults() async throws {
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[0] = .success(
          Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
        )
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let searchStore = client.store(for: Mountain.searchQuery(.recommended))

        // NB: Ensure the store exists in the client prior to fetching.
        let mountainStore = client.store(for: Mountain.query(id: Mountain.mock1.id))

        try await searchStore.fetchNextPage()
        expectNoDifference(mountainStore.currentValue, .mock1)
      }
    }

    @Test("Caches Individual Mountains", .disabled())
    func cachesIndividualMountains() async throws {
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[0] = .success(
          Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
        )
        $0[Mountain.SearcherKey.self] = searcher
        $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(nil))
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let searchStore = client.store(for: Mountain.searchQuery(.recommended))
        try await searchStore.fetchNextPage()

        let mountainStore = client.store(for: Mountain.query(id: Mountain.mock1.id))

        try await confirmation { confirm in
          let handler = QueryEventHandler<Mountain.Query.State>(
            onResultReceived: { result, context in
              guard context.queryResultUpdateReason == .yieldedResult else { return }
              expectNoDifference(try? result.get(), .mock1)
              confirm()
            }
          )
          try await mountainStore.fetch(handler: handler)
        }
      }
    }
  }
}
