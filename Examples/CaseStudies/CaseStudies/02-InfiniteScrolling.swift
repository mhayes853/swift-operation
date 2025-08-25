import SharingOperation
import SwiftUI

// MARK: - InfiniteScrollingCaseStudy

struct InfiniteScrollingCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Infinite Scrolling"
  let description: LocalizedStringKey = """
    Infinite scrolling allows users to easily navigate paginated data in your application. We'll \
    use the `InfiniteQueryRequest` to power the list for each tag. When the user reaches the \
    bottom of the list. We'll call `fetchNextPage` on the infinite query to get the next page in \
    the list.

    You can also pull to refresh the list, which is done through the `refreshable` view modifier. \
    Inside the closure for the modifier, we'll call `load` on the `@SharedOperation` property to \
    reload the initial page of the query. This will reset the query state to just the initial page.

    Additionally, the like button will update the post in the list by writing directly to the \
    `@SharedOperation` property that observes the state of the query. This will update the state of \
    the query in the underyling `OperationStore` backing `@SharedOperation`, and so other parts of the app \
    will be able to see the update.
    """

  var content: some View {
    Section("Posts by Tags") {
      NavigationLink("History") {
        PostsListView(tag: "History")
      }
      NavigationLink("Crime") {
        PostsListView(tag: "Crime")
      }
      NavigationLink("Mystery") {
        PostsListView(tag: "Mystery")
      }
      NavigationLink("Life") {
        PostsListView(tag: "Life")
      }
    }
  }
}

// MARK: - PostsListView

private struct PostsListView: View {
  @SharedOperation<Post.ListByTagQuery.State>
  private var list: InfiniteQueryPagesFor<Post.ListByTagQuery>

  let tag: String

  struct DisplayedPost: Identifiable, Hashable, Sendable {
    let pageId: Post.ListPage.ID
    let id: Int
  }

  @State private var displayedPost: DisplayedPost?

  init(tag: String) {
    self.tag = tag
    self._list = SharedOperation(Post.listByTagQuery(tag: tag), animation: .bouncy)
  }

  var body: some View {
    List {
      BasicInfiniteQueryStateView(state: self.$list.state) { pages in
        Text("Tap on any of the posts to view them in full!")

        ForEach(pages) { page in
          ForEach(page.value.posts) { post in
            PostView(post: post) {
              self.$list.withLock { $0.updateLike(for: post.id, on: page.id) }
            }
            .frame(height: 200)
            .onTapGesture {
              self.displayedPost = DisplayedPost(pageId: page.id, id: post.id)
            }
          }
        }

        if self.$list.isLoadingNextPage {
          ProgressView()
        } else if !self.$list.hasNextPage {
          Text("You've reached the end of the list.")
        } else {
          ProgressView()
            .onAppear {
              Task { try await self.$list.fetchNextPage() }
            }
        }
      }
    }
    .navigationTitle(self.tag)
    .refreshable { try? await self.$list.load() }
    .sheet(item: self.$displayedPost) { displayedPost in
      if let post = self.list[id: displayedPost.pageId]?.value.posts[id: displayedPost.id] {
        PostView(post: post) {
          self.$list.withLock { $0.updateLike(for: displayedPost.id, on: displayedPost.pageId) }
        }
        .padding()
        .presentationDetents([.medium])
      }
    }
  }
}

extension InfiniteQueryPagesFor<Post.ListByTagQuery> {
  fileprivate mutating func updateLike(for postId: Int, on pageId: Post.ListPage.ID) {
    guard var post = self[id: pageId]?.value.posts[id: postId] else { return }
    post.likeCount += post.isUserLiking ? -1 : 1
    post.isUserLiking.toggle()
    self[id: pageId]?.value.posts[id: postId] = post
  }
}

#Preview {
  InfiniteScrollingCaseStudy()
}
