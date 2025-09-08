import CanIClimbKit
import CustomDump
import Dependencies
import SharingOperation
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("Mountain+Search tests")
  struct MountainSearchTests {
    @Test("Seeds Query Client With Detail Results After Page Fetch")
    func seedsOperationClientWithDetailResults() async throws {
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[.recommended(page: 0)] = .success(
          Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
        )
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        @Dependency(\.defaultOperationClient) var client
        let searchStore = client.store(for: Mountain.searchQuery(.recommended))

        try await searchStore.fetchNextPage()

        let mountainStore = client.store(for: Mountain.query(id: Mountain.mock1.id))
        expectNoDifference(mountainStore.currentValue, .mock1)
      }
    }

    @Test("Seeds Query Client With Prexisting Detail Results After Page Fetch")
    func seedsOperationClientWithPreExistingDetailResults() async throws {
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[.recommended(page: 0)] = .success(
          Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
        )
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        @Dependency(\.defaultOperationClient) var client
        let searchStore = client.store(for: Mountain.searchQuery(.recommended))

        // NB: Ensure the store exists in the client prior to fetching.
        let mountainStore = client.store(for: Mountain.query(id: Mountain.mock1.id))

        try await searchStore.fetchNextPage()
        expectNoDifference(mountainStore.currentValue, .mock1)
      }
    }

    @Test("Yields Cached Mountains When Unable To Search Remotely On Page 0")
    func yieldsCachedMountainsWhenUnableToSearchRemotely() async throws {
      struct SomeError: Error {}

      var mountain = Mountain.mock1
      mountain.name = "Mt Test"

      let request = Mountain.SearchRequest.recommended(page: 0, text: "te")

      await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.localResults = [mountain]
        searcher.results[request] = .failure(SomeError())
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        @Dependency(\.defaultOperationClient) var client

        await confirmation { confirm in
          let handler = PaginatedEventHandler<Mountain.SearchQuery.State>(
            onPageResultReceived: { [mountain] _, result, context in
              guard
                context.operationResultUpdateReason == .yieldedResult && context.isLastRetryAttempt
              else { return }
              expectNoDifference(
                try? result.get(),
                Page(
                  id: 0,
                  value: Mountain.SearchResult(mountains: [mountain], hasNextPage: true)
                )
              )
              confirm()
            }
          )
          let searchStore = client.store(for: Mountain.searchQuery(request.search))
          await #expect(throws: SomeError.self) {
            try await searchStore.fetchNextPage(handler: handler)
          }
        }
      }
    }

    @Test("Does Not Yield Cached Mountains When Fetching Past The First Page")
    func doesNotYieldCachedMountainsWhenFetchingPastTheFirstPage() async throws {
      struct SomeError: Error {}

      let mountain1 = Mountain.mock1

      var mountain2 = mountain1
      mountain2.id = Mountain.ID()
      mountain2.name = "Mt Test"

      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.localResults = [mountain2]
        searcher.results[.recommended(page: 0)] = .success(
          Mountain.SearchResult(mountains: [mountain1], hasNextPage: true)
        )
        searcher.results[.recommended(page: 1)] = .failure(SomeError())
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        @Dependency(\.defaultOperationClient) var client
        let searchStore = client.store(for: Mountain.searchQuery(.recommended))

        try await searchStore.fetchNextPage()
        await #expect(throws: SomeError.self) {
          try await searchStore.fetchNextPage()
        }

        expectNoDifference(
          searchStore.currentValue.map(\.value),
          [Mountain.SearchResult(mountains: [mountain1], hasNextPage: true)],
          "There should only be 1 page because no cached data should be yielded after page 0."
        )
      }
    }
  }
}
