@testable import CaseStudies
import SharingQuery
import Dependencies
import DependenciesTestSupport
import Testing
import CustomDump

@MainActor
@Suite("02-OptimisticUpdates tests", .dependencies { $0[PostsKey.self] = MockPosts() })
struct OptimisticUpdatesTests {
  @Test("Adds Like To Post When Interacting With Like")
  func addsLikeToPostWhenInteracting() async throws {
    let model = OptimisticUpdatesModel(id: 1)
    _ = try await model.$post.activeTasks.first?.runIfNeeded()
    
    let interactor = MockInteractor { _, _ in
      expectNoDifference(model.post??.likeCount, 1)
      expectNoDifference(model.post??.isUserLiking, true)
    }
    await withDependencies {
      $0[PostInteractorKey.self] = interactor
    } operation: {
      expectNoDifference(model.post??.likeCount, 0)
      expectNoDifference(model.post??.isUserLiking, false)
      
      await model.likeInvoked()
      
      expectNoDifference(model.post??.likeCount, 1)
      expectNoDifference(model.post??.isUserLiking, true)
    }
  }
  
  @Test("Removes Like From Post When Interacting With Unlike")
  func removesLikeFromPostWhenInteracting() async throws {
    let model = OptimisticUpdatesModel(id: 1)
    _ = try await model.$post.activeTasks.first?.runIfNeeded()
    
    await withDependencies {
      $0[PostInteractorKey.self] = MockInteractor { _, _ in }
    } operation: {
      await model.likeInvoked()
    }
    
    let interactor = MockInteractor { _, _ in
      expectNoDifference(model.post??.likeCount, 0)
      expectNoDifference(model.post??.isUserLiking, false)
    }
    await withDependencies {
      $0[PostInteractorKey.self] = interactor
    } operation: {
      expectNoDifference(model.post??.likeCount, 1)
      expectNoDifference(model.post??.isUserLiking, true)
      
      await model.likeInvoked()
      
      expectNoDifference(model.post??.likeCount, 0)
      expectNoDifference(model.post??.isUserLiking, false)
    }
  }
  
  @Test("Removes Optimistic Update When Interaction Fails")
  func removesOptimisticUpdate() async throws {
    struct SomeError: Error {}
    
    let model = OptimisticUpdatesModel(id: 1)
    _ = try await model.$post.activeTasks.first?.runIfNeeded()
    
    await withDependencies {
      $0[PostInteractorKey.self] = MockInteractor { _, _ in throw SomeError() }
    } operation: {
      expectNoDifference(model.post??.likeCount, 0)
      expectNoDifference(model.post??.isUserLiking, false)
      
      await model.likeInvoked()
      
      expectNoDifference(model.post??.likeCount, 0)
      expectNoDifference(model.post??.isUserLiking, false)
    }
  }
  
  @Test("Presents Alert When Error Occurs")
  func presentsAlertWhenErrorOccurs() async throws {
    struct SomeError: Error {}
    
    let model = OptimisticUpdatesModel(id: 1)
    _ = try await model.$post.activeTasks.first?.runIfNeeded()
    
    await withDependencies {
      $0[PostInteractorKey.self] = MockInteractor { _, _ in throw SomeError() }
    } operation: {
      expectNoDifference(model.alert, nil)
      await model.likeInvoked()
      expectNoDifference(model.alert, .failure(interaction: .like))
    }
  }
}

private struct MockPosts: Posts {
  func post(with id: Int) async throws -> Post? {
    Post(id: id, title: "Mock", content: "This is a test", likeCount: 0, isUserLiking: false)
  }
}

private struct MockInteractor: Post.Interactor {
  let interact: @MainActor @Sendable (Int, Post.Interaction) async throws -> Void
  
  func applyInteraction(to postId: Int, interaction: Post.Interaction) async throws {
    try await self.interact(postId, interaction)
  }
}
