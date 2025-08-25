import CustomDump
import Dependencies
import DependenciesTestSupport
import SharingOperation
import Testing

@testable import CaseStudies

@MainActor
@Suite("03-Debouncing tests")
struct DebouncingCaseStudyTests {
  @Test("Debounces Search Results")
  func debouncesSearchResults() async throws {
    let clock = TestClock()

    try await withDependencies {
      $0.continuousClock = clock
      $0[PostSearcherKey.self] = MockSearcher(results: ["": [.mock1], "blob": [.mock2]])
    } operation: {
      let model = DebouncingModel(debounceTime: .seconds(1))
      try await model.$posts.load()

      model.text = "blo"

      expectNoDifference(model.$posts.activeTasks.count, 0)
      expectNoDifference(model.$posts.wrappedValue, [.mock1])

      await clock.advance(by: .seconds(0.5))

      model.text = "blob"
      expectNoDifference(model.$posts.activeTasks.count, 0)
      expectNoDifference(model.$posts.wrappedValue, [.mock1])

      await clock.advance(by: .seconds(0.5))

      expectNoDifference(model.$posts.activeTasks.count, 0)
      expectNoDifference(model.$posts.wrappedValue, [.mock1])

      await clock.advance(by: .seconds(0.5))

      try await model.waitForSearchingToBegin()

      _ = try await model.$posts.activeTasks.first?.runIfNeeded()
      expectNoDifference(model.$posts.wrappedValue, [.mock2])
    }
  }
}

extension Post {
  fileprivate static let mock1 = Post(
    id: 1,
    title: "Mock 1",
    content: "",
    likeCount: 20,
    isUserLiking: false
  )
  fileprivate static let mock2 = Post(
    id: 2,
    title: "Mock 2",
    content: "",
    likeCount: 20,
    isUserLiking: false
  )
}

private struct MockSearcher: Post.Searcher {
  let results: [String: IdentifiedArrayOf<Post>]

  func search(by text: String) async throws -> IdentifiedArrayOf<Post> {
    self.results[text] ?? []
  }
}
