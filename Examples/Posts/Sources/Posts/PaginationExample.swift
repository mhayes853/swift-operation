import Foundation
import SharingOperation
import SwiftUI

// MARK: - FeedPage

extension Post {
  struct FeedPage: Codable, Sendable {
    let posts: [Post]
    let total: Int
    let skip: Int
  }
}

// MARK: - FeedQuery

extension Post {
  static let feedQuery = FeedQuery()

  struct FeedQuery: PaginatedRequest, Hashable, Sendable {
    private static let limit = 10

    let initialPageId = 0

    func pageId(
      after page: Page<Int, FeedPage>,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext
    ) -> Int? {
      // Nil means there's no more pages to fetch.
      page.value.skip < page.value.total ? page.id + 1 : nil
    }

    func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext,
      with continuation: OperationContinuation<FeedPage, any Error>
    ) async throws -> FeedPage {
      var url = URL(string: "https://dummyjson.com/posts")!
      url.append(
        queryItems: [
          URLQueryItem(name: "limit", value: "\(Self.limit)"),
          URLQueryItem(name: "skip", value: "\(paging.pageId * Self.limit)")
        ]
      )
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(FeedPage.self, from: data)
    }
  }
}

// MARK: - PostsFeedView

struct PostsFeedView: View {
  @SharedOperation(Post.feedQuery) private var feed

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 10) {
        ForEach(self.feed) { page in
          ForEach(page.value.posts) { post in
            PostDetailView(post: post)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        if let error = self.$feed.error {
          Text("Error: \(error.localizedDescription)")
        }
        Button(self.$feed.isLoading ? "Loading..." : "Load More") {
          Task { try await self.$feed.fetchNextPage() }
        }
      }
    }
  }
}

#Preview {
  PostsFeedView()
}
