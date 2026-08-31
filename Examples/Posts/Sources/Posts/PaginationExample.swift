import Dependencies
import Foundation
import SharingOperation
import SwiftUI

// MARK: - FeedPage

extension Post {
  package struct FeedPage: Codable, Hashable, Sendable {
    package let posts: [Post]
    package let total: Int
    package let skip: Int

    package init(posts: [Post], total: Int, skip: Int) {
      self.posts = posts
      self.total = total
      self.skip = skip
    }
  }
}

// MARK: - FeedQuery

extension Post {
  package static let feedQuery = FeedQuery()

  package struct FeedQuery: PaginatedRequest, Hashable, Sendable {
    private static let limit = 10

    package let initialPageId = 0

    package func pageId(
      after page: Page<Int, FeedPage>,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext
    ) -> Int? {
      // Nil means there's no more pages to fetch.
      page.value.skip + page.value.posts.count < page.value.total ? page.id + 1 : nil
    }

    package func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext,
      with continuation: OperationContinuation<FeedPage, any Error>
    ) async throws -> FeedPage {
      @Dependency(HTTPDataTransportKey.self) var transport
      var url = URL(string: "https://dummyjson.com/posts")!
      url.append(
        queryItems: [
          URLQueryItem(name: "limit", value: "\(Self.limit)"),
          URLQueryItem(name: "skip", value: "\(paging.pageId * Self.limit)")
        ]
      )
      let (data, _) = try await transport.data(for: URLRequest(url: url))
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
          Task { try? await self.$feed.fetchNextPage() }
        }
        .disabled(self.$feed.isLoading || !self.$feed.hasNextPage)
      }
    }
  }
}

#Preview {
  PostsFeedView()
}
