import CanIClimbKit
import CustomDump
import Dependencies
import DependenciesTestSupport
import Operation
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite(
    "MountainsListModel tests",
    .dependencies {
      $0.continuousClock = ImmediateClock()
    }
  )
  struct MountainsListModelTests {
    @Test("Refetches When Search Category Changes")
    func refetchesWhenSearchCategoryChanges() async throws {
      let recommendedResult = Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
      let plannedResult = Mountain.SearchResult(mountains: [.mock2], hasNextPage: false)
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[.recommended(page: 0)] = .success(recommendedResult)
        searcher.results[.planned(page: 0)] = .success(plannedResult)
        $0[Mountain.SearcherKey.self] = searcher
      } operation: {
        let model = MountainsListModel()

        _ = try await model.$mountains.initialPageActiveTasks.first?.runIfNeeded()
        expectNoDifference(model.mountains, [PaginatedPage(id: 0, value: recommendedResult)])

        model.category = .planned
        _ = try await model.$mountains.initialPageActiveTasks.first?.runIfNeeded()
        expectNoDifference(model.mountains, [PaginatedPage(id: 0, value: plannedResult)])
      }
    }

    @Test("Debounces Textual Searches")
    func debouncesTextualSearches() async throws {
      let noTextResult = Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
      let textResult = Mountain.SearchResult(mountains: [.mock2], hasNextPage: false)

      let clock = TestClock()
      let debounceDuration = Duration.seconds(1)
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[.recommended(page: 0)] = .success(noTextResult)
        searcher.results[.recommended(page: 0, text: "blob")] = .success(textResult)
        $0[Mountain.SearcherKey.self] = searcher
        $0.continuousClock = clock
      } operation: {
        let model = MountainsListModel(searchDebounceDuration: debounceDuration)

        _ = try await model.$mountains.initialPageActiveTasks.first?.runIfNeeded()
        expectNoDifference(model.mountains, [PaginatedPage(id: 0, value: noTextResult)])

        model.searchText = "blob"
        expectNoDifference(model.$mountains.initialPageActiveTasks, [])

        await clock.advance(by: debounceDuration)
        _ = try await model.$mountains.initialPageActiveTasks.first?.runIfNeeded()
        expectNoDifference(model.mountains, [PaginatedPage(id: 0, value: textResult)])
      }
    }

    @Test("Cancels Debounced Search When Changing Category")
    func cancelsDebouncedSearchWhenChangingCategory() async throws {
      let noTextResult = Mountain.SearchResult(mountains: [.mock1], hasNextPage: false)
      let textResult = Mountain.SearchResult(mountains: [.mock2], hasNextPage: false)
      let plannedResult = Mountain.SearchResult(mountains: [], hasNextPage: false)

      let clock = TestClock()
      let debounceDuration = Duration.seconds(1)
      try await withDependencies {
        let searcher = Mountain.MockSearcher()
        searcher.results[.recommended(page: 0)] = .success(noTextResult)
        searcher.results[.recommended(page: 0, text: "blob")] = .success(textResult)
        searcher.results[.planned(page: 0, text: "blob")] = .success(plannedResult)
        $0[Mountain.SearcherKey.self] = searcher
        $0.continuousClock = clock
      } operation: {
        let model = MountainsListModel(searchDebounceDuration: debounceDuration)

        _ = try await model.$mountains.initialPageActiveTasks.first?.runIfNeeded()
        expectNoDifference(model.mountains, [PaginatedPage(id: 0, value: noTextResult)])

        model.searchText = "blob"
        expectNoDifference(model.$mountains.initialPageActiveTasks, [])

        model.category = .planned
        _ = try await model.$mountains.initialPageActiveTasks.first?.runIfNeeded()
        expectNoDifference(model.mountains, [PaginatedPage(id: 0, value: plannedResult)])

        await clock.advance(by: debounceDuration)
        model.category = .recommended
        expectNoDifference(
          model.$mountains.valueUpdateCount,
          0,
          "The query should not have been updated because the debounce should have been cancelled."
        )
      }
    }
  }
}
