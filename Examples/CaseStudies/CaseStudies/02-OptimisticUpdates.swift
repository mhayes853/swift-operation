import Dependencies
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - OptimisticUpdatesCaseStudy

struct OptimisticUpdatesCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Optimistic Updates"
  let description: LocalizedStringKey = """
    An optimistic update refers to updating data to reflect the final result of a query before \
    such a query finishes. If the query fails, you can always undo the optimistic update on the \
    data.

    In this example, when the like button is pressed on a post, we'll immediately increment the \
    like counter to make the view as responsive as possible inside a `MutationRequest`. However, \
    if the mutation fails, we'll revert the like. We can achieve this by accessing the \
    default `QueryClient` inside the mutation. Then, we access the underlying `QueryStore` that \
    powers the post query, and update its `likeCount` appropriately.

    While the optimistic update logic could be placed inside `OptimisticUpdatesModel`, doing so would only \
    constrain the update to the local model. By performing the update inside the mutation, we \
    ensure that the opmtimism is bound to the mutation, which could be used in many parts of your \
    app. Additionally, _all_ screens that display the post in your app will get the optimistic \
    update.
    """

  @State private var model = OptimisticUpdatesModel(id: 1)

  var content: some View {
    Text("Like and unlike the post! (There is a 50% chance that an error alert will appear.)")

    BasicQueryStateView(state: self.model.$post.state) { post in
      if let post {
        PostView(post: post) {
          Task { await self.model.likeInvoked() }
        }
      } else {
        Text("Post not found.")
      }
    }
    .alert(self.$model.alert) { _ in }
  }
}

// MARK: - PostModel

@MainActor
@Observable
final class OptimisticUpdatesModel {
  @ObservationIgnored
  @SharedQuery<Post.Query.State> var post: Post??

  @ObservationIgnored
  @SharedQuery(Post.interactMutation) var interact: Void?

  var alert: AlertState<AlertAction>?

  init(id: Int) {
    self._post = SharedQuery(Post.query(for: id), animation: .bouncy)
  }
}

extension OptimisticUpdatesModel {
  func likeInvoked() async {
    guard let optionalPost = self.post, let post = optionalPost else { return }
    let interaction = post.isUserLiking ? Post.Interaction.unlike : .like
    do {
      try await self.$interact.mutate(
        with: Post.InteractMutation.Arguments(postId: post.id, interaction: interaction)
      )
    } catch {
      self.alert = .failure(interaction: interaction)
    }
  }
}

// MARK: - AlertState

extension OptimisticUpdatesModel {
  enum AlertAction: Hashable, Sendable {}
}

extension AlertState where Action == OptimisticUpdatesModel.AlertAction {
  static func failure(interaction: Post.Interaction) -> Self {
    Self {
      let title =
        switch interaction {
        case .like: "Like"
        case .unlike: "Unlike"
        }
      return TextState("Failed to \(title) Post")
    } message: {
      TextState("The optimistic update has been removed.")
    }
  }
}

// MARK: - Mutation

extension Post {
  enum Interaction: Hashable, Sendable {
    case like
    case unlike
  }

  static let interactMutation = InteractMutation().retry(limit: 0)

  struct InteractMutation: MutationRequest, Hashable {
    struct Arguments: Sendable {
      let postId: Int
      let interaction: Interaction
    }

    func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(\.defaultQueryClient) var client
      @Dependency(PostInteractorKey.self) var interactor
      let postStore = client.store(for: Post.query(for: arguments.postId))

      do {
        postStore.currentValue??.updateLikes(with: arguments.interaction)
        try await interactor.applyInteraction(
          to: arguments.postId,
          interaction: arguments.interaction
        )
      } catch {
        postStore.currentValue??.updateLikes(with: arguments.interaction.inverse)
        throw error
      }
    }
  }
}

extension Post.Interaction {
  fileprivate var inverse: Self {
    switch self {
    case .like: .unlike
    case .unlike: .like
    }
  }
}

extension Post {
  fileprivate mutating func updateLikes(with interaction: Interaction) {
    switch interaction {
    case .like:
      self.likeCount += 1
      self.isUserLiking = true
    case .unlike:
      self.likeCount -= 1
      self.isUserLiking = false
    }
  }
}

// MARK: - Interactor

extension Post {
  protocol Interactor: Sendable {
    func applyInteraction(to postId: Int, interaction: Interaction) async throws
  }
}

struct FlakeyPostInteractor: Post.Interactor {
  func applyInteraction(to postId: Int, interaction: Post.Interaction) async throws {
    try await Task.sleep(for: .seconds(1))
    if Bool.random() {
      throw SomeError()
    }
  }

  private struct SomeError: Error {}
}

enum PostInteractorKey: DependencyKey {
  static let liveValue: any Post.Interactor = FlakeyPostInteractor()
}

#Preview {
  NavigationStack {
    OptimisticUpdatesCaseStudy()
  }
}
