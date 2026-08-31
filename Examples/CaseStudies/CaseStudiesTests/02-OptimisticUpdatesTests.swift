import CustomDump
import Dependencies
import SharingOperation
import Testing

@testable import CaseStudies

@MainActor
@Suite("02-OptimisticUpdates tests")
struct OptimisticUpdatesTests {
  @Test("Adds Like To Post When Interacting With Like")
  func addsLikeToPostWhenInteracting() async throws {
    try await self.withMockPosts {
      let model = OptimisticUpdatesModel(id: 1)
      _ = try await model.$post.activeTasks.first?.runIfNeeded()

      let interactor = MockInteractor { _, _ in
        expectNoDifference(model.post??.likeCount, 1)
        expectNoDifference(model.post??.isUserLiking, true)
      }
      await withCaseStudiesDependencies {
        $0[PostInteractorKey.self] = interactor
      } operation: {
        expectNoDifference(model.post??.likeCount, 0)
        expectNoDifference(model.post??.isUserLiking, false)

        await model.likeInvoked()

        expectNoDifference(model.post??.likeCount, 1)
        expectNoDifference(model.post??.isUserLiking, true)
      }
    }
  }

  @Test("Removes Like From Post When Interacting With Unlike")
  func removesLikeFromPostWhenInteracting() async throws {
    try await self.withMockPosts {
      let model = OptimisticUpdatesModel(id: 1)
      _ = try await model.$post.activeTasks.first?.runIfNeeded()

      await withCaseStudiesDependencies {
        $0[PostInteractorKey.self] = MockInteractor { _, _ in }
      } operation: {
        await model.likeInvoked()
      }

      let interactor = MockInteractor { _, _ in
        expectNoDifference(model.post??.likeCount, 0)
        expectNoDifference(model.post??.isUserLiking, false)
      }
      await withCaseStudiesDependencies {
        $0[PostInteractorKey.self] = interactor
      } operation: {
        expectNoDifference(model.post??.likeCount, 1)
        expectNoDifference(model.post??.isUserLiking, true)

        await model.likeInvoked()

        expectNoDifference(model.post??.likeCount, 0)
        expectNoDifference(model.post??.isUserLiking, false)
      }
    }
  }

  @Test("Removes Optimistic Update When Interaction Fails")
  func removesOptimisticUpdate() async throws {
    struct SomeError: Error {}

    try await self.withMockPosts {
      let model = OptimisticUpdatesModel(id: 1)
      _ = try await model.$post.activeTasks.first?.runIfNeeded()

      await withCaseStudiesDependencies {
        $0[PostInteractorKey.self] = MockInteractor { _, _ in throw SomeError() }
      } operation: {
        expectNoDifference(model.post??.likeCount, 0)
        expectNoDifference(model.post??.isUserLiking, false)

        await model.likeInvoked()

        expectNoDifference(model.post??.likeCount, 0)
        expectNoDifference(model.post??.isUserLiking, false)
      }
    }
  }

  @Test("Presents Alert When Error Occurs")
  func presentsAlertWhenErrorOccurs() async throws {
    struct SomeError: Error {}

    try await self.withMockPosts {
      let model = OptimisticUpdatesModel(id: 1)
      _ = try await model.$post.activeTasks.first?.runIfNeeded()

      await withCaseStudiesDependencies {
        $0[PostInteractorKey.self] = MockInteractor { _, _ in throw SomeError() }
      } operation: {
        expectNoDifference(model.alert, nil)
        await model.likeInvoked()
        expectNoDifference(model.alert, .failure(interaction: .like))
      }
    }
  }

  private func withMockPosts<R>(operation: () async throws -> R) async rethrows -> R {
    try await withCaseStudiesDependencies {
      $0[PostsKey.self] = MockPosts()
    } operation: {
      try await operation()
    }
  }
}

private struct MockPosts: Posts {
  func post(with id: Int) async throws -> Post? {
    Post(id: id, title: "Mock", content: "This is a test", likeCount: 0, isUserLiking: false)
  }

  func search(by text: String) async throws -> IdentifiedArrayOf<Post> {
    []
  }
}

private struct MockInteractor: Post.Interactor {
  let interact: @MainActor @Sendable (Int, Post.Interaction) async throws -> Void

  func applyInteraction(to postId: Int, interaction: Post.Interaction) async throws {
    try await self.interact(postId, interaction)
  }
}
